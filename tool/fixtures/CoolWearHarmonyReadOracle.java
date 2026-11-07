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
 }
}
