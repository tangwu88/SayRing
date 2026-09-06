import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier,context,next){return next(specifier.startsWith('.')&&context.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(specifier)?specifier+'.ts':specifier,context);} });
const { trendWindow,shiftTrendDay,trendRecords,trendFieldNames,trendSeries,trendSummary,spreadChartX,spreadChartPoints,spreadChartIndex,plotSeries,waveformPoints,localDateKey }=await import('../entry/src/main/ets/model/HealthTrend.ts');
const units={distance:'km',temperature:'c'};
const value=(name,value,unit='BPM')=>({name,value,unit});
const record=(id,day,values,metric='heart',deviceKey='test-device')=>({id,deviceKey,metric,timestamp:new Date(`${day}T12:00:00`).getTime(),source:'watch_history',values,samples:[],sampleFrequency:0});
test('day week and month use local calendar boundaries in either host timezone',()=>{
  assert.equal(trendWindow('2026-09-06','day').start,new Date(2026,8,6).getTime());
  assert.equal(localDateKey(trendWindow('2026-09-06','week').start),'2026-08-31');
  assert.equal(localDateKey(trendWindow('2026-09-06','week').end),'2026-09-07');
  assert.equal(localDateKey(trendWindow('2026-02-20','month').end),'2026-03-01');
  assert.equal(shiftTrendDay('2026-03-31','month',-1),'2026-02-01');
  assert.throws(()=>trendWindow('2026-02-31','day'));
});
test('range is end-exclusive and never mixes device metric or duplicate ids',()=>{
  const window=trendWindow('2026-09-06','day');
  const a=record('a','2026-09-06',[value('心率',70)]);
  const b={...a,id:'b',timestamp:window.end};
  assert.deepEqual(trendRecords([a,a,b,{...a,id:'c',deviceKey:'other'},{...a,id:'d',metric:'oxygen'}],'heart','test-device',window),[a]);
});
test('summary only uses available samples and objective previous period change',()=>{
  const records=[record('a','2026-09-06',[value('心率',60)]),record('b','2026-09-06',[value('心率',80)])];
  assert.deepEqual(trendSummary(records,[record('p','2026-09-05',[value('心率',65)])],'心率',units),{name:'心率',unit:'BPM',count:2,min:60,max:80,average:70,change:5});
  assert.equal(trendSummary([],[],'心率',units),undefined);
  assert.equal(trendSummary([records[0]],[],'心率',units).average,60);
});
test('blood pressure keeps two named values and a separate pulse statistic',()=>{
  const records=[record('a','2026-09-06',[value('收缩压',128,'mmHg'),value('舒张压',82,'mmHg'),value('脉搏',70)],'pressure')];
  assert.deepEqual(trendFieldNames(records),['收缩压','舒张压','脉搏']);
  assert.equal(trendSummary(records,[],'收缩压',units).average,128);
  assert.equal(trendSummary(records,[],'舒张压',units).average,82);
});
test('compound metrics use names and units without mixing incomparable fields',()=>{
  const records=[record('a','2026-09-06',[value('BMI',22,''),value('体脂率',18,'%')],'bodyComposition')];
  assert.equal(trendSeries(records,'BMI','day',units).points[0].value,22);
  assert.equal(trendSeries(records,'体脂率','day',units).unit,'%');
  assert.equal(trendSeries(records,'尿酸','day',units).points.length,0);
});
test('daily aggregation skips missing days and activity counters are not added repeatedly',()=>{
  const records=[record('a','2026-09-01',[value('步数',400,'步')],'activity'),record('b','2026-09-01',[value('步数',800,'步')],'activity'),record('c','2026-09-03',[value('步数',600,'步')],'activity')];
  assert.deepEqual(trendSeries(records,'步数','month',units).points.map(p=>p.value),[800,600]);
  assert.deepEqual(trendSummary(records,[],'步数',units),{name:'步数',unit:'步',count:2,min:600,max:800,average:700,change:undefined});
  const heart=records.map(r=>({...r,metric:'heart',values:[value('心率',r.values[0].value/10)]}));
  assert.deepEqual(trendSeries(heart,'心率','month',units).points.map(p=>p.value),[60,60]);
});
test('temperature conversion happens before chart and summary while originals survive',()=>{
  const records=[record('a','2026-09-06',[value('体温',36.5,'°C')],'temperature')];
  assert.equal(trendSummary(records,[],'体温',{...units,temperature:'f'}).average,97.7);
  assert.equal(records[0].values[0].value,36.5);
});
test('ECG has no invented average and a constant real waveform remains constant',()=>{
  assert.equal(trendSummary([record('e','2026-09-06',[value('HRV',42,'ms')],'ecg')],[],'HRV',units),undefined);
  assert.deepEqual(waveformPoints([5,5,5],100),[[0,112],[50,112],[100,112]]);
  assert.deepEqual(waveformPoints([],100),[]);assert.deepEqual(waveformPoints([1,NaN],100),[]);
});
test('display chart spreads nearby real samples and keeps a single sample visible',()=>{
  const start=new Date(2026,8,6,10,25).getTime();
  const series={name:'收缩压',unit:'mmHg',points:[
    {time:start,value:121,recordId:'a'},{time:start+5*60*1000,value:127,recordId:'b'}
  ]};
  assert.deepEqual(spreadChartPoints(series,121,127,240),[[0,144],[240,16]]);
  assert.equal(spreadChartX(0,1,240),120);
  assert.deepEqual(spreadChartPoints({...series,points:series.points.slice(0,1)},121,127,240),[[120,144]]);
});
test('display chart touch selects and clamps the nearest visible sample',()=>{
  assert.equal(spreadChartIndex(-10,240,2),0);
  assert.equal(spreadChartIndex(180,240,3),2);
  assert.equal(spreadChartIndex(300,240,3),2);
  assert.equal(spreadChartIndex(50,240,1),0);
});
test('sleep stages are not collapsed into unrelated metrics',()=>{
  const records=[record('s','2026-09-06',[value('总睡眠',420,'分钟'),value('深睡',120,'分钟'),value('浅睡',270,'分钟'),value('清醒',30,'分钟')],'sleep')];
  assert.deepEqual(trendFieldNames(records),['总睡眠','深睡','浅睡','清醒']);
  assert.equal(trendSummary(records,[],'深睡',units).average,120);
});
test('dense plot is bounded, preserves actual peaks and never changes source statistics',()=>{
  const points=Array.from({length:20000},(_,i)=>({time:i,value:i===10000?9999: i===10100?-9999:Math.sin(i),recordId:String(i)}));
  const series={name:'合成波形',unit:'',points};
  const drawn=plotSeries(series,256);
  assert.ok(drawn.points.length<=256);assert.equal(points.length,20000);
  assert.deepEqual(drawn.points[0],points[0]);assert.deepEqual(drawn.points.at(-1),points.at(-1));
  for(const point of drawn.points)assert.equal(point,points[Number(point.recordId)]);
  assert.ok(drawn.points.includes(points[10000]));assert.ok(drawn.points.includes(points[10100]));
  assert.ok(drawn.points.every((p,i)=>i===0||p.time>drawn.points[i-1].time));
  assert.equal(plotSeries({name:'x',unit:'',points:points.slice(0,1)}).points.length,1);
});
