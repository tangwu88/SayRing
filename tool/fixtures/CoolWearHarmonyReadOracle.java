import ce.com.cenewbluesdk.entity.CEDevData;
import ce.com.cenewbluesdk.queue.CEProtocolB;
public final class CoolWearHarmonyReadOracle {
 public static void main(String[] args) {
  for(int type:new int[]{2,3}) for(int n:new int[]{0,7,255}) for(int cmd:new int[]{3,-10001}){
   CEDevData data=new CEDevData();data.setDataType(type);data.setN(n);data.setCmd(cmd);
   byte[] bytes=new CEProtocolB(1).getSendData(data).getSendData();StringBuilder hex=new StringBuilder();
   for(byte b:bytes)hex.append(String.format("%02x",b&255));
   System.out.println(type+":"+n+":"+cmd+":"+hex);
  }
  CEDevData response=new CEDevData();response.setCmd(1);response.setDataType(2);response.setN(7);response.setData(new byte[]{12,1,2,3,4,5,6});
  byte[] wire=new CEProtocolB(1).getSendData(response).getSendData();byte[] shortFrame=java.util.Arrays.copyOf(wire,17);
  CEDevData decoded=new CEProtocolB(1).Analysis(shortFrame);if(decoded==null||decoded.getData().length!=7)throw new AssertionError("SDK short notification rejected");
  StringBuilder hex=new StringBuilder();for(byte b:shortFrame)hex.append(String.format("%02x",b&255));System.out.println("short:"+hex);
  CEProtocolB roleProtocol=new CEProtocolB(1);CEDevData peer=new CEProtocolB(101).Analysis(new CEProtocolB(101).getSendData(response).getSendData());
  byte[] peerWire=new CEProtocolB(101).getSendData(response).getSendData();peer=roleProtocol.Analysis(peerWire);
  byte[] roleAck=roleProtocol.getSendData(peer).getSendData();StringBuilder ahex=new StringBuilder();for(byte b:roleAck)ahex.append(String.format("%02x",b&255));System.out.println("role-ack:"+ahex);
  CEDevData battery=new CEDevData();battery.setCmd(3);battery.setDataType(3);battery.setN(2);byte[] next=roleProtocol.getSendData(battery).getSendData();StringBuilder qhex=new StringBuilder();for(byte b:next)qhex.append(String.format("%02x",b&255));System.out.println("role-query:"+qhex);
  for(int bit=0;bit<256;bit++){byte[] b=new byte[32];b[bit/8]=(byte)(1<<(bit%8));ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_FUNCTION_CONTROL c=new ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_FUNCTION_CONTROL(b);System.out.println("cap:"+bit+":"+c.isHr_measure_button()+":"+c.isHasO2()+":"+c.isHasHR24H());}
  for(int state=0;state<=1;state++) for(int role:new int[]{1,101}) for(int metric=0;metric<2;metric++){
   CEDevData request=metric==0?new ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_REAL_HR(state).toCEDevData():new ce.com.cenewbluesdk.entity.k6.K6_DATA_TYPE_REAL_O2(state).toCEDevData();request.setN(4);
   byte[] frame=new CEProtocolB(role).getSendData(request).getSendData();StringBuilder hexControl=new StringBuilder();for(byte b:frame)hexControl.append(String.format("%02x",b&255));System.out.println("control:"+metric+":"+state+":"+role+":"+hexControl);
  }
 }
}
