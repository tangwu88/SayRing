import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
registerHooks({resolve(specifier,context,next){return next(specifier.startsWith('.')&&context.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(specifier)?`${specifier}.ts`:specifier,context)}});
const { commerceCents, commerceMoney, commerceImages, parseProductDetail, purchaseError, parseCart, selectionFields,
  parseCheckout, checkoutError, parseOrderDetail, parseShipments, orderHeading } = await import('../entry/src/main/ets/model/CommerceContracts.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { ApiError } = await import('../entry/src/main/ets/model/Contracts.ts');
const now=Date.now(), envelope=data=>({code:200,data});
async function clientWith(request){const vault={value:{accessToken:'fixture',refreshToken:'fixture-refresh',expiresAt:now+3600000,memberId:'1',displayName:'合成账号'},async read(){return this.value},async write(value){this.value=value},async clear(){this.value=undefined}};const client=new AccountClient({request},vault,()=>now);await client.restore();return client;}
const product={id:7,name:'合成商品',price:'12.30',min_buy:2,sku:[{id:9,name:'A',price:'12.30',stock:4},{id:10,name:'B',price:'15.00',stock:0}]};
const rawPreview={preview:{product_money:'24.60',shipping_money:'2.00'},account:{money1:'5.00'},products:[{product_name:'合成商品',product_money:'24.60',sku_id:9,num:2}]};
const rawOrder={id:8,order_sn:'SYNTHETIC-ONLY',order_status:2,pay_money:'26.60',order_money:'24.60',product:[{id:81,product_name:'合成商品',sku_id:9,product_money:'24.60',num:2}]};
const preview=parseCheckout(rawPreview);
test('money is precise and missing values cannot become free products',()=>{
  assert.equal(commerceCents('12.30'),1230);assert.equal(commerceCents(0),0);assert.equal(commerceCents('0.29'),29);
  for(const v of ['',undefined,null,'NaN','-1','1e3','0.001','Infinity'])assert.equal(commerceCents(v),-1);
  assert.equal(commerceMoney(-1),'价格待确认');assert.equal(commerceMoney(1230),'¥12.30');
});
test('real product covers support JSON, arrays and objects, reject private and third party URLs',()=>{
  assert.deepEqual(commerceImages('[{"url":"/attachment/a.jpg"},{"src":"/attachment/a.jpg"}]'),['https://app.saidian.cc/attachment/a.jpg']);
  for(const v of ['https://other.test/a.jpg','/api/v1/member/my','/attachment/../token','javascript:alert(1)'])assert.deepEqual(commerceImages(v),[]);
});
test('product parsing and SKU selection preserve real prices and unknown stock',()=>{
  const detail=parseProductDetail(product,7);assert.equal(detail.skus[0].priceCents,1230);assert.equal(detail.minBuy,2);
  assert.equal(purchaseError(detail,detail.skus[0],2),'');assert.ok(purchaseError(detail,detail.skus[0],1));assert.ok(purchaseError(detail,detail.skus[0],5));
  assert.ok(purchaseError(detail,detail.skus[1],2));assert.ok(purchaseError(detail,undefined,2));
  assert.throws(()=>parseProductDetail(product,8));assert.throws(()=>parseProductDetail({},7));
  assert.equal(parseProductDetail({...product,sku:[{id:9,name:'A'}]},7).skus[0].stock,-1);
});
test('detail content uses the shared safe image/text parser, never executes HTML',()=>{
  const detail=parseProductDetail({...product,intro:'<script>alert(1)</script><p>真实介绍</p><img src="/attachment/p.jpg">'},7);
  assert.deepEqual(detail.blocks.map(b=>b.kind),['text','image']);assert.equal(detail.blocks[0].text,'真实介绍');
});
test('cart mapping distinguishes cart item id from SKU and honors actual quantity',()=>{
  const cart=parseCart({cartList:[{id:51,sku_id:9,number:2,price:'12.30',product:{id:7,name:'合成商品',stock:4}}]});
  assert.equal(cart[0].id,51);assert.equal(cart[0].skuId,9);assert.equal(cart[0].quantity,2);assert.equal(cart[0].priceCents,1230);
  for(const v of [undefined,{},[{id:1}],[{id:1,sku_id:9,number:0}]])assert.throws(()=>parseCart(v));
  assert.deepEqual(parseCart([]),[]);
});
test('buy-now and cart checkout preserve existing iOS endpoint semantics without cart writes',()=>{
  assert.deepEqual(selectionFields([{skuId:9,quantity:2}]),[{name:'type',value:'buy_now'},{name:'data',value:'{"sku_id":9,"num":2}'},{name:'is_channel',value:'0'}]);
  const cart=parseCart([{id:51,sku_id:9,number:2},{id:52,sku_id:10,number:1}]);
  assert.equal(selectionFields([{skuId:9,quantity:2},{skuId:10,quantity:1}],cart)[1].value,'51,52');
  assert.throws(()=>selectionFields([{skuId:9,quantity:1},{skuId:10,quantity:1}],cart));
  assert.throws(()=>selectionFields([{skuId:9,quantity:2},{skuId:9,quantity:2}],cart));assert.throws(()=>selectionFields([]));
});
test('preview rejects missing money and validates points, address and message',()=>{
  assert.equal(preview.productCents,2460);assert.equal(preview.shippingCents,200);assert.equal(checkoutError(preview,'1','5',''), '');
  assert.ok(checkoutError(preview,'','0',''));assert.ok(checkoutError(preview,'1','5.01',''));assert.ok(checkoutError(preview,'1','-1',''));
  assert.ok(checkoutError(preview,'1','0','a'.repeat(101)));
  assert.throws(()=>parseCheckout({products:[{}],preview:{product_money:'24.60'}}));assert.throws(()=>parseCheckout({}));
  assert.equal(checkoutError({...preview,pointsCents:-1},'1','0',''),'');assert.ok(checkoutError({...preview,pointsCents:-1},'1','1',''));
});
test('order detail has explicit status, identity and money; zero-paid orders remain readable',()=>{
  const result=parseOrderDetail(rawOrder,8);assert.equal(result.order.status,2);assert.equal(result.products[0].id,81);
  assert.equal(result.products[0].quantity,2);assert.equal(orderHeading(2),'等待收货');
  assert.equal(parseOrderDetail({...rawOrder,pay_money:'0.00'},8).order.amountCents,0);
  assert.throws(()=>parseOrderDetail(rawOrder,9));assert.throws(()=>parseOrderDetail({...rawOrder,order_status:undefined},8));
  assert.equal(result.products[0].totalPrice,true);
  assert.equal(parseCart([{id:51,sku_id:9,number:2,price:'12.30',product_money:'24.60'}])[0].priceCents,1230);
  assert.equal(parseCart([{id:51,sku_id:9,number:2,price:'12.30'}])[0].totalPrice,false);
});
test('shipment empty and failed states are not conflated',()=>{
  assert.deepEqual(parseShipments({data:[]}),[]);assert.throws(()=>parseShipments({}));
  assert.equal(parseShipments({data:[{express_company:'合成快递',express_no:'SYNTHETIC',trace:[{remark:'已发出',datetime:'2026-09-06'}]}]})[0].traces[0].remark,'已发出');
});
test('product request uses public contract without login headers',async()=>{
  const client=await clientWith(async(path,fields,session)=>{assert.equal(path,'/api/inv-shop/v1/product/product/view?id=7');assert.equal(session,undefined);return envelope(product)});
  assert.equal((await client.shopProductDetail(7)).skus.length,2);
});
test('checkout preview is read only and URL encodes the exact selection',async()=>{
  const client=await clientWith(async(path,fields,session,body,method)=>{
    assert.ok(session);assert.equal(fields,undefined);assert.equal(body,undefined);assert.notEqual(method,'POST');
    assert.equal(path,'/api/inv-shop/v1/order/order/preview?type=buy_now&data=%7B%22sku_id%22%3A9%2C%22num%22%3A2%7D&is_channel=0');return envelope(rawPreview);
  });assert.equal((await client.shopCheckout([{skuId:9,quantity:2}])).productCents,2460);
});
test('cart updates read authoritative state after the intentional write',async()=>{
  const calls=[];const client=await clientWith(async(path,fields)=>{calls.push([path,fields]);return envelope(path.endsWith('/index')?[{id:51,sku_id:9,number:2,price:'12.30'}]:{})});
  assert.equal((await client.changeShopCart(9,2,'quantity'))[0].quantity,2);
  assert.equal(calls[0][0],'/api/inv-shop/v1/member/cart-item/update-num');assert.deepEqual(calls[0][1],[{name:'sku_id',value:'9'},{name:'num',value:'2'}]);
  assert.equal(calls[1][0],'/api/inv-shop/v1/member/cart-item/index');
});
test('order creation reconfirms preview and accepts only a stable server ID',async()=>{
  let body;const client=await clientWith(async(path,fields,session,json)=>{if(path.includes('/preview?'))return envelope(rawPreview);body=JSON.parse(json);return envelope({order_id:8})});
  assert.equal(await client.createCommerceOrder([{skuId:9,quantity:2}],preview,'1','2.00',' 合成留言 '),8);
  assert.deepEqual(body,{merchant_id:0,is_channel:0,address_id:1,buyer_message:'合成留言',shipping_type:1,type:'buy_now',data:'{"sku_id":9,"num":2}',point:2});
});
test('price changes, missing order ID, offline and missing endpoints never become order success',async()=>{
  let writes=0;const changed=await clientWith(async(path)=>{if(path.includes('/preview?'))return envelope({...rawPreview,preview:{product_money:'99.00',shipping_money:'2.00'}});writes++;return envelope({id:8})});
  await assert.rejects(changed.createCommerceOrder([{skuId:9,quantity:2}],preview,'1','0',''));assert.equal(writes,0);
  const missing=await clientWith(async path=>envelope(path.includes('/preview?')?rawPreview:{}));
  await assert.rejects(missing.createCommerceOrder([{skuId:9,quantity:2}],preview,'1','0',''));
  for(const status of [0,404,405]){const client=await clientWith(async()=>{throw new ApiError('不可用',status)});await assert.rejects(client.shopCheckout([{skuId:9,quantity:2}]));}
});
test('simultaneous order clicks issue only one create request',async()=>{
  let release;const gate=new Promise(r=>release=r);let writes=0;
  const client=await clientWith(async(path)=>{if(path.includes('/preview?')){await gate;return envelope(rawPreview)}writes++;return envelope({id:8})});
  const first=client.createCommerceOrder([{skuId:9,quantity:2}],preview,'1','0','');
  await assert.rejects(client.createCommerceOrder([{skuId:9,quantity:2}],preview,'1','0',''));release();await first;assert.equal(writes,1);
});
test('receipt reconfirms awaiting-receipt state and reads status after success',async()=>{
  const paths=[];const client=await clientWith(async(path)=>{paths.push(path);return envelope(path.includes('/view?')?{...rawOrder,order_status:paths.length===3?3:2}:{})});
  assert.equal((await client.confirmShopReceipt(8)).order.status,3);assert.equal(paths[1],'/api/inv-shop/v1/member/order/take-delivery');
  const stale=await clientWith(async()=>envelope({...rawOrder,order_status:0}));await assert.rejects(stale.confirmShopReceipt(8));
});
test('refund uses order product id and rejects processed entries and excessive amounts',async()=>{
  let fields;const client=await clientWith(async(path,params)=>{if(path.includes('/refund-apply')){fields=params;return envelope({})}return envelope({...rawOrder,product:[{...rawOrder.product[0],is_customer:fields?1:0}]})});
  const result=await client.applyShopRefund(8,81,1,'2.00','合成原因');assert.equal(result.products[0].applied,true);
  assert.equal(fields.find(f=>f.name==='id').value,'81');assert.equal(fields.find(f=>f.name==='refund_require_money').value,'2.00');
  await assert.rejects(client.applyShopRefund(8,81,1,'2.00','合成原因'));
  const other=await clientWith(async()=>envelope(rawOrder));await assert.rejects(other.applyShopRefund(8,81,1,'30','合成原因'));await assert.rejects(other.applyShopRefund(8,81,1,'1',''));
});
test('source routes cover commerce pages with fixed actions and no fake success buttons',()=>{
  const ui=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  for(const route of ['shop-cart','shop-checkout','shop-order-detail','shop-express','shop-after-sales','shop-refund'])assert.ok(ui.includes(`this.screen === '${route}'`));
  for(const id of ['product_buy','purchase_confirm','checkout_submit','cart_checkout','order_payment','refund_submit'])assert.ok(ui.includes(`.id('${id}')`));
  assert.ok(ui.includes('this.checkoutAttempted = true'));assert.ok(ui.includes('this.checkoutAddress = address; this.back()'));
});
test('post-create cart cleanup verifies order lines and never deletes unselected or changed quantities',async()=>{
  const deleted=[];const client=await clientWith(async(path,fields)=>{
    if(path.includes('/view?'))return envelope(rawOrder);
    if(path.endsWith('/index'))return envelope([{id:51,sku_id:9,number:2},{id:52,sku_id:10,number:1}]);
    deleted.push(fields[0].value);return envelope({});
  });
  assert.equal(await client.removeCreatedCartItems(8,[{skuId:9,quantity:2}]),true);assert.deepEqual(deleted,['9']);
  assert.equal(await client.removeCreatedCartItems(8,[{skuId:10,quantity:1}]),false);assert.deepEqual(deleted,['9']);
  const changed=await clientWith(async path=>envelope(path.includes('/view?')?rawOrder:[{id:51,sku_id:9,number:3}]));
  assert.equal(await changed.removeCreatedCartItems(8,[{skuId:9,quantity:2}]),false);
});
