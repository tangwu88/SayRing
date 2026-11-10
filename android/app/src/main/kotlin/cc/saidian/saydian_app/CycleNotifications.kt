package cc.saidian.saydian_app

import android.app.*
import android.content.*
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/** 周期日程只展示通用文案；不启动蓝牙、红屏、报警音或戒指振动。 */
internal class CycleNotifications(private val activity:Activity,messenger:BinaryMessenger) {
 init { MethodChannel(messenger,"cn.saydian.ring/cycle").setMethodCallHandler { call,result ->
  val prefs=CycleSchedule.prefs(activity)
  when(call.method){
   "owner"->{val next=call.argument<String>("owner")?.takeIf{it.matches(Regex("[a-f0-9]{64}"))};val old=prefs.getString("owner",null);if(old!=next){CycleSchedule.cancel(activity);prefs.edit().putString("owner",next).remove("opened").apply()};result.success(null)}
   "schedule"->{
    val owner=call.argument<String>("owner")
    if(owner==null||owner!=prefs.getString("owner",null)){result.success(false)}else{
     val plans=call.argument<List<Map<String,Any>>>("plans")?:emptyList()
     if(plans.size>40||plans.any{!CycleSchedule.valid(it)}){result.success(false)}else{
      CycleSchedule.cancel(activity)
      prefs.edit().putString("plans",JSONArray(plans).toString()).putString("locale",call.argument<String>("locale") ?: "en").apply()
      if(call.argument<Boolean>("request")==true&&Build.VERSION.SDK_INT>=33&&activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED){activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),27158)}
      CycleSchedule.install(activity)
      result.success(NotificationManagerCompat.from(activity).areNotificationsEnabled())
     }
    }
   }
   "consumeOpen"->{val intent=activity.intent;val owner=call.argument<String>("owner");val valid=intent?.action==CycleSchedule.OPEN&&owner==prefs.getString("owner",null)&&intent.getStringExtra("cycle-owner")==owner&&prefs.getString("plans","[]")!!.contains(intent.getStringExtra("cycle-plan")?:"INVALID");if(intent?.action==CycleSchedule.OPEN){intent.action=null};result.success(valid)}
   else->result.notImplemented()
  }
 }}
}
internal object CycleSchedule {
 const val OPEN="cn.saydian.ring.CYCLE_OPEN"
 private const val CHANNEL="sayring-cycle-records-v1"
 fun prefs(c:Context)=c.getSharedPreferences("sayring-cycle-v1",Context.MODE_PRIVATE)
 fun valid(p:Map<String,Any>):Boolean = (p["id"] as? String)?.matches(Regex("cycle-[a-f0-9]{64}"))==true && (p["date"] as? String)?.matches(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}"))==true && (p["hour"] as? Number)?.toInt() in 0..23 && (p["minute"] as? Number)?.toInt() in 0..59
 private fun intent(c:Context,id:String)=Intent(c,CycleReminderReceiver::class.java).setAction("cn.saydian.ring.CYCLE_FIRE").setData(Uri.parse("sayring-cycle://plan/$id"))
 private fun pending(c:Context,id:String)=PendingIntent.getBroadcast(c,0,intent(c,id),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
 fun cancel(c:Context){
  val prefs=prefs(c);val owner=prefs.getString("owner",null);val alarm=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
  val plans=JSONArray(prefs.getString("plans","[]"));for(i in 0 until plans.length()){alarm.cancel(pending(c,plans.getJSONObject(i).getString("id")))}
  val manager=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
  if(Build.VERSION.SDK_INT>=23)manager.activeNotifications.filter{it.tag=="sayring-cycle-$owner"}.forEach{manager.cancel(it.tag,it.id)}
  prefs.edit().remove("plans").apply()
 }
 fun at(p:JSONObject):Long{
  val d=p.getString("date").split('-');val cal=Calendar.getInstance();cal.isLenient=false
  cal.set(d[0].toInt(),d[1].toInt()-1,d[2].toInt(),p.getInt("hour"),p.getInt("minute"),0);cal.set(Calendar.MILLISECOND,0);return cal.timeInMillis
 }
 fun install(c:Context){
  if(prefs(c).getString("owner",null)==null)return
  val plans=JSONArray(prefs(c).getString("plans","[]"));val alarm=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
  for(i in 0 until plans.length()){val p=plans.getJSONObject(i);try{val time=at(p);if(time>System.currentTimeMillis())alarm.setWindow(AlarmManager.RTC_WAKEUP,time,10*60*1000,pending(c,p.getString("id")))}catch(_:Exception){/* 无效日期不安排，不补发过去日程。 */}}
 }
 fun fire(c:Context,id:String){
  val prefs=prefs(c);val owner=prefs.getString("owner",null)?:return;val plans=JSONArray(prefs.getString("plans","[]"));val p=(0 until plans.length()).map{plans.getJSONObject(it)}.firstOrNull{it.getString("id")==id}?:return
  val now=System.currentTimeMillis();val target=try{at(p)}catch(_:Exception){return};if(now<target||now-target>6*60*60*1000||!NotificationManagerCompat.from(c).areNotificationsEnabled())return
  val delivered="delivered-$owner-$id";if(prefs.getBoolean(delivered,false))return
  val manager=c.getSystemService(Context.NOTIFICATION_SERVICE)as NotificationManager
  val chinese=prefs.getString("locale","en")?.startsWith("zh")==true
  if(Build.VERSION.SDK_INT>=26)manager.createNotificationChannel(NotificationChannel(CHANNEL,if(chinese) "周期记录" else "Cycle tracking",NotificationManager.IMPORTANCE_DEFAULT).apply{enableVibration(false)})
  val open=Intent(c,MainActivity::class.java).setAction(OPEN).setData(Uri.parse("sayring-cycle://$owner/$id")).putExtra("cycle-owner",owner).putExtra("cycle-plan",id).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
  val pi=PendingIntent.getActivity(c,0,open,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  val n=NotificationCompat.Builder(c,CHANNEL).setSmallIcon(c.applicationInfo.icon).setContentTitle(if(chinese) "记录提醒" else "Tracking reminder").setContentText(if(chinese) "您有一条记录提醒，请打开查看。" else "You have a tracking reminder. Open the app to view it.").setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setPriority(NotificationCompat.PRIORITY_DEFAULT).setContentIntent(pi).setAutoCancel(true).build()
  try{manager.notify("sayring-cycle-$owner",id.hashCode(),n);prefs.edit().putBoolean(delivered,true).apply()}catch(_:SecurityException){}
 }
}
class CycleReminderReceiver:BroadcastReceiver(){override fun onReceive(context:Context,intent:Intent){val id=intent.data?.lastPathSegment?:return;CycleSchedule.fire(context,id)}}
class CycleRescheduleReceiver:BroadcastReceiver(){override fun onReceive(context:Context,intent:Intent){CycleSchedule.install(context)}}
