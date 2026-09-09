import { SHARED_TRANSLATIONS } from './GlobalSharedTranslations';
import { NATIVE_TRANSLATIONS } from './GlobalNativeTranslations';
import { CRITICAL_TRANSLATIONS } from './GlobalCriticalTranslations';
import { ENGLISH_FALLBACKS } from './GlobalEnglishFallbacks';

export const APP_LOCALES: string[] = ['en', 'zh-Hans', 'zh-Hant', 'de', 'fr', 'es', 'ja', 'ko'];
export const APP_LANGUAGE_NAMES: string[] = ['English', '简体中文', '繁體中文', 'Deutsch', 'Français', 'Español', '日本語', '한국어'];
const translations: Record<string, string[]> = {
  "language": ["Language","语言","語言","Sprache","Langue","Idioma","言語","언어"],
  "email": ["Email","邮箱","電子郵件","E-Mail","E-mail","Correo electrónico","メール","이메일"],
  "phone": ["Phone number","手机号","手機號碼","Telefonnummer","Téléphone","Teléfono","電話番号","전화번호"],
  "country": ["Country / region","国家或地区","國家或地區","Land / Region","Pays / région","País / región","国・地域","국가/지역"],
  "login": ["Log in","登录","登入","Anmelden","Se connecter","Iniciar sesión","ログイン","로그인"],
  "logging_in": ["Logging in…","正在登录…","正在登入…","Anmeldung…","Connexion…","Iniciando sesión…","ログイン中…","로그인 중…"],
  "register": ["Create account","注册账户","建立帳戶","Konto erstellen","Créer un compte","Crear cuenta","アカウント作成","계정 만들기"],
  "register_title": ["Register","注册","註冊","Registrieren","Inscription","Registro","登録","가입"],
  "password": ["Password","密码","密碼","Passwort","Mot de passe","Contraseña","パスワード","비밀번호"],
  "confirm_password": ["Confirm password","确认密码","確認密碼","Passwort bestätigen","Confirmer le mot de passe","Confirmar contraseña","パスワードを確認","비밀번호 확인"],
  "new_password": ["New password (8–72 characters)","新密码（8–72位）","新密碼（8–72字元）","Neues Passwort (8–72 Zeichen)","Nouveau mot de passe (8–72 caractères)","Nueva contraseña (8–72 caracteres)","新しいパスワード（8〜72文字）","새 비밀번호(8~72자)"],
  "forgot_password": ["Forgot password?","忘记密码？","忘記密碼？","Passwort vergessen?","Mot de passe oublié ?","¿Olvidaste la contraseña?","パスワードをお忘れですか？","비밀번호를 잊으셨나요?"],
  "reset_password": ["Reset password","重置密码","重設密碼","Passwort zurücksetzen","Réinitialiser le mot de passe","Restablecer contraseña","パスワードを再設定","비밀번호 재설정"],
  "code": ["Verification code","验证码","驗證碼","Bestätigungscode","Code de vérification","Código de verificación","確認コード","인증 코드"],
  "send_code": ["Send code","获取验证码","取得驗證碼","Code senden","Envoyer le code","Enviar código","コードを送信","코드 전송"],
  "sending": ["Sending…","发送中…","傳送中…","Wird gesendet…","Envoi…","Enviando…","送信中…","전송 중…"],
  "code_sent": ["Code sent. Check your email or messages.","验证码已发送，请查看邮件或短信。","驗證碼已傳送，請查看郵件或簡訊。","Code gesendet. Bitte E-Mail oder SMS prüfen.","Code envoyé. Consultez vos e-mails ou SMS.","Código enviado. Revisa tu correo o SMS.","コードを送信しました。メールまたはSMSをご確認ください。","코드를 보냈습니다. 이메일 또는 문자를 확인하세요."],
  "terms_intro": ["I have read and agree to","我已阅读并同意","我已閱讀並同意","Ich habe gelesen und akzeptiere","J’ai lu et j’accepte","He leído y acepto","以下を読み、同意します","다음을 읽고 동의합니다"],
  "terms": ["Terms of Service","用户协议","使用者協議","Nutzungsbedingungen","Conditions d’utilisation","Términos de uso","利用規約","이용약관"],
  "privacy": ["Privacy Policy","隐私政策","隱私權政策","Datenschutz","Politique de confidentialité","Política de privacidad","プライバシーポリシー","개인정보 처리방침"],
  "accept_terms": ["Please agree to the Terms and Privacy Policy.","请先同意用户协议与隐私政策。","請先同意使用者協議與隱私權政策。","Bitte Bedingungen und Datenschutz zustimmen.","Veuillez accepter les conditions et la confidentialité.","Acepta los términos y la política de privacidad.","利用規約とプライバシーポリシーに同意してください。","이용약관과 개인정보 처리방침에 동의해 주세요."],
  "invalid_email": ["Enter a valid email address.","请输入有效的邮箱地址。","請輸入有效的電子郵件地址。","Gültige E-Mail-Adresse eingeben.","Saisissez une adresse e-mail valide.","Introduce un correo electrónico válido.","有効なメールアドレスを入力してください。","올바른 이메일 주소를 입력해 주세요."],
  "invalid_phone": ["Enter a valid number including the country code.","请输入包含国际区号的有效手机号。","請輸入含國際區碼的有效手機號碼。","Gültige Nummer mit Ländervorwahl eingeben.","Saisissez un numéro valide avec indicatif pays.","Introduce un número válido con prefijo internacional.","国番号を含む有効な電話番号を入力してください。","국가번호를 포함한 올바른 전화번호를 입력해 주세요."],
  "invalid_code": ["Enter the 6-digit verification code.","请输入6位验证码。","請輸入6位驗證碼。","6-stelligen Code eingeben.","Saisissez le code à 6 chiffres.","Introduce el código de 6 dígitos.","6桁の確認コードを入力してください。","6자리 인증 코드를 입력해 주세요."],
  "password_length": ["Use 8–72 characters for your password.","密码长度须为8–72位。","密碼長度須為8–72字元。","Passwort mit 8–72 Zeichen verwenden.","Utilisez un mot de passe de 8 à 128 caractères.","Usa una contraseña de 8 a 128 caracteres.","パスワードは8〜72文字にしてください。","비밀번호는 8~72자로 입력해 주세요."],
  "password_mismatch": ["The passwords do not match.","两次密码不一致。","兩次密碼不一致。","Die Passwörter stimmen nicht überein.","Les mots de passe ne correspondent pas.","Las contraseñas no coinciden.","パスワードが一致しません。","비밀번호가 일치하지 않습니다."],
  "request_code_first": ["Request a code for this account first.","请先为此帐号获取验证码。","請先為此帳戶取得驗證碼。","Zuerst einen Code für dieses Konto anfordern.","Demandez d’abord un code pour ce compte.","Solicita primero un código para esta cuenta.","まずこのアカウントのコードを取得してください。","먼저 이 계정의 코드를 요청해 주세요."],
  "auth_unavailable": ["Account services are unavailable. Please retry.","帐号服务暂不可用，请重试。","帳戶服務暫時無法使用，請重試。","Kontodienst nicht verfügbar. Bitte erneut versuchen.","Service de compte indisponible. Réessayez.","Servicio de cuentas no disponible. Reintenta.","アカウントサービスを利用できません。再試行してください。","계정 서비스를 이용할 수 없습니다. 다시 시도해 주세요."],
  "verification_unavailable": ["Could not send a code. Please retry later.","验证码暂时无法发送，请稍后重试。","驗證碼暫時無法傳送，請稍後重試。","Code konnte nicht gesendet werden. Später erneut versuchen.","Impossible d’envoyer un code. Réessayez plus tard.","No se pudo enviar el código. Inténtalo más tarde.","コードを送信できません。しばらくしてから再試行してください。","코드를 보낼 수 없습니다. 나중에 다시 시도해 주세요."],
  "channel_unavailable": ["This verification option is currently unavailable.","此验证方式暂不可用。","此驗證方式暫時無法使用。","Diese Bestätigungsmethode ist derzeit nicht verfügbar.","Cette méthode de vérification est indisponible.","Esta opción de verificación no está disponible.","この確認方法は現在利用できません。","현재 이 인증 방법을 이용할 수 없습니다."],
  "country_unavailable": ["Text verification is unavailable in this country.","此国家或地区暂不支持短信验证。","此國家或地區暫不支援簡訊驗證。","SMS-Bestätigung ist in diesem Land nicht verfügbar.","Vérification par SMS indisponible dans ce pays.","La verificación por SMS no está disponible en este país.","この国・地域ではSMS確認を利用できません。","이 국가/지역에서는 문자 인증을 이용할 수 없습니다."],
  "invalid_session": ["Please log in again.","请重新登录。","請重新登入。","Bitte erneut anmelden.","Veuillez vous reconnecter.","Vuelve a iniciar sesión.","もう一度ログインしてください。","다시 로그인해 주세요."],
  "session_expired": ["Your session has expired. Please log in again.","登录已过期，请重新登录。","登入已過期，請重新登入。","Sitzung abgelaufen. Bitte erneut anmelden.","Session expirée. Reconnectez-vous.","La sesión ha caducado. Vuelve a iniciar sesión.","セッションの有効期限が切れました。再度ログインしてください。","세션이 만료되었습니다. 다시 로그인해 주세요."],
  "retry": ["Retry","重试","重試","Erneut versuchen","Réessayer","Reintentar","再試行","다시 시도"],
  "save": ["Save","保存","儲存","Speichern","Enregistrer","Guardar","保存","저장"],
  "cancel": ["Cancel","取消","取消","Abbrechen","Annuler","Cancelar","キャンセル","취소"],
  "confirm": ["Confirm","确认","確認","Bestätigen","Confirmer","Confirmar","確認","확인"],
  "back": ["Back","返回","返回","Zurück","Retour","Volver","戻る","뒤로"],
  "health": ["Health","健康","健康","Gesundheit","Santé","Salud","健康","건강"],
  "device": ["Device","设备","裝置","Gerät","Appareil","Dispositivo","デバイス","기기"],
  "mine": ["Me","我的","我的","Ich","Moi","Yo","マイページ","내 정보"],
  "home": ["Home","首页","首頁","Start","Accueil","Inicio","ホーム","홈"],
  "settings": ["Settings","设置","設定","Einstellungen","Réglages","Ajustes","設定","설정"],
  "account": ["Account","帐号","帳戶","Konto","Compte","Cuenta","アカウント","계정"],
  "logout": ["Log out","退出登录","登出","Abmelden","Se déconnecter","Cerrar sesión","ログアウト","로그아웃"],
  "connect_watch": ["Connect watch","连接手表","連接手錶","Uhr verbinden","Connecter la montre","Conectar reloj","腕時計を接続","시계 연결"],
  "add_device": ["Add device","添加设备","新增裝置","Gerät hinzufügen","Ajouter un appareil","Añadir dispositivo","デバイス追加","기기 추가"],
  "sync": ["Sync data","同步数据","同步資料","Daten synchronisieren","Synchroniser","Sincronizar datos","データ同期","데이터 동기화"],
  "disconnect": ["Disconnect","断开连接","中斷連線","Trennen","Déconnecter","Desconectar","接続解除","연결 해제"],
  "connected": ["Connected","已连接","已連線","Verbunden","Connecté","Conectado","接続済み","연결됨"],
  "disconnected": ["Not connected","未连接","未連線","Nicht verbunden","Non connecté","No conectado","未接続","연결되지 않음"],
  "loading": ["Loading…","加载中","載入中","Wird geladen…","Chargement…","Cargando…","読み込み中…","불러오는 중…"],
  "messages": ["Messages","消息","訊息","Nachrichten","Messages","Mensajes","メッセージ","메시지"],
  "no_data": ["No data yet","暂无数据","尚無資料","Noch keine Daten","Aucune donnée","Sin datos","データなし","데이터 없음"],
  "heart_rate": ["Heart rate","心率","心率","Herzfrequenz","Fréquence cardiaque","Frecuencia cardíaca","心拍数","심박수"],
  "blood_pressure": ["Blood pressure","血压","血壓","Blutdruck","Tension artérielle","Presión arterial","血圧","혈압"],
  "oxygen": ["Blood oxygen","血氧","血氧","Blutsauerstoff","Oxygène sanguin","Oxígeno en sangre","血中酸素","혈중 산소"],
  "temperature": ["Temperature","体温","體溫","Temperatur","Température","Temperatura","体温","체온"],
  "ecg": ["ECG","心电","心電","EKG","ECG","ECG","心電図","심전도"],
  "activity": ["Activity","运动","運動","Aktivität","Activité","Actividad","運動","운동"],
  "history": ["History","历史记录","歷史紀錄","Verlauf","Historique","Historial","履歴","기록"],
  "profile": ["Profile","个人资料","個人資料","Profil","Profil","Perfil","プロフィール","프로필"],
  "reports": ["Health reports","健康报告","健康報告","Gesundheitsberichte","Rapports de santé","Informes de salud","健康レポート","건강 보고서"],
  "shop": ["Shop","商城","商城","Shop","Boutique","Tienda","ショップ","쇼핑"],
  "care": ["Family care","远程关爱","遠端關愛","Familienfürsorge","Suivi des proches","Cuidado familiar","家族ケア","가족 돌봄"],
  "about": ["About","关于我们","關於我們","Über uns","À propos","Acerca de","アプリについて","앱 정보"],
  "display_units": ["Units","单位设置","單位設定","Einheiten","Unités","Unidades","単位","단위"],
  "language_note": ["App language only. Your watch language will stay unchanged.","仅修改App语言，不改变手表语言。","僅修改App語言，不更改手錶語言。","Nur App-Sprache. Die Sprache der Uhr bleibt unverändert.","Langue de l’app uniquement. La montre reste inchangée.","Solo cambia el idioma de la app, no el del reloj.","アプリの言語のみ変更します。腕時計の言語は変わりません。","앱 언어만 변경됩니다. 시계 언어는 그대로 유지됩니다."],
};
let activeLocale: string = 'en';
Object.keys(CRITICAL_TRANSLATIONS).forEach((key: string) => { translations[key] = CRITICAL_TRANSLATIONS[key]; });
Object.keys(NATIVE_TRANSLATIONS).forEach((key: string) => { translations[key] = NATIVE_TRANSLATIONS[key]; });
Object.keys(SHARED_TRANSLATIONS).forEach((key: string) => {
  if (!translations[key]) translations[key] = SHARED_TRANSLATIONS[key];
});
export function normalizeAppLocale(locale: string): string { return APP_LOCALES.includes(locale) ? locale : 'en'; }
export function currentAppLocale(): string { return activeLocale; }
export function setAppLocale(locale: string): void { activeLocale = normalizeAppLocale(locale); }
export function appText(keyOrText: string, locale: string = activeLocale): string {
  const index = APP_LOCALES.indexOf(normalizeAppLocale(locale));
  const direct = translations[keyOrText];
  if (direct) return direct[index] || direct[0];
  const key = Object.keys(translations).find(key => translations[key].includes(keyOrText));
  if (key) return translations[key][index] || translations[key][0];
  const fallback = ENGLISH_FALLBACKS[keyOrText] || ENGLISH_FALLBACKS[keyOrText.replace(/\n/g, '\\n')];
  return index !== 1 && fallback ? fallback : keyOrText;
}
export function formatAppText(key: string, values: Record<string, string>, locale: string = activeLocale): string {
  let text = appText(key, locale);
  Object.keys(values).forEach((name: string) => { text = text.split('{' + name + '}').join(values[name]); });
  return text;
}
export function translationKeys(): string[] { return Object.keys(translations); }
