// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get scanLocationTitle => 'Activer la localisation';

  @override
  String get scanLocationHint =>
      'Activez la localisation de votre téléphone, puis revenez ici pour rechercher les bagues à proximité.';

  @override
  String get scanPermissionTitle => 'Autoriser l’accès aux appareils';

  @override
  String get scanPermissionHint =>
      'Accordez les autorisations nécessaires dans les réglages, puis revenez rechercher votre bague.';

  @override
  String get loginProtectionTitle => 'Protection de la connexion';

  @override
  String get verifyContactToReset =>
      'Vérifiez votre adresse e-mail ou votre numéro de téléphone pour réinitialiser le mot de passe.';

  @override
  String get workoutStartOnWatch =>
      'Cette bague ne peut pas démarrer un entraînement depuis l’application. Démarrez-le directement sur la bague.';

  @override
  String get finishWorkoutConfirm => 'Terminer cet entraînement ?';

  @override
  String get finishLeaveWorkoutHint =>
      'Avant de quitter, l’activité sur la bague s’arrêtera et la durée et le parcours enregistrés seront sauvegardés.';

  @override
  String get finishAndLeave => 'Terminer et quitter';

  @override
  String get workoutRouteMissing =>
      'Aucun parcours enregistré par le téléphone n’est disponible pour cette séance. Les données d’activité de la bague sont conservées.';

  @override
  String get workoutDuration => 'Durée de l’entraînement';

  @override
  String get workoutWatchHeartRate => 'Fréquence cardiaque de la bague';

  @override
  String get messageSendFailed =>
      'Échec de l’envoi. Vérifiez votre connexion et réessayez.';

  @override
  String get noWatchShopHint =>
      'Besoin d’un autre appareil ? Visitez la boutique Say Ring.';

  @override
  String get notificationInAppHint =>
      'Les messages et les indicateurs de non-lecture restent disponibles dans l’application. Activez les notifications pour recevoir rapidement les invitations de partage et les alertes de santé.';

  @override
  String get healthAlertSafetyHint =>
      'Les alertes de santé servent à vous avertir à temps, pas à établir un diagnostic médical. En cas de malaise important, consultez rapidement.';

  @override
  String get afterSalesService => 'Service après-vente';

  @override
  String get afterSalesApplyHint =>
      'Choisissez l’article et indiquez le motif et le montant demandé. Après l’envoi, consultez le statut dans vos commandes.';

  @override
  String get afterSalesAlreadySubmitted =>
      'Une demande après-vente a déjà été envoyée pour cet article. Veuillez attendre son examen par l’équipe de la boutique.';

  @override
  String get afterSalesType => 'Type de demande';

  @override
  String get requestedAmount => 'Montant demandé';

  @override
  String get afterSalesReason => 'Motif de la demande';

  @override
  String get describeProblem => 'Décrivez le problème';

  @override
  String get amountPaid => 'Montant payé';

  @override
  String get orderDetailsLoadFailed =>
      'Impossible de charger les détails de la commande. Veuillez réessayer plus tard.';

  @override
  String get confirmItemReceived => 'Avez-vous reçu les articles ?';

  @override
  String get confirmReceiptHint =>
      'La confirmation de réception clôturera la commande. Ne confirmez pas si vous n’avez pas reçu les articles.';

  @override
  String get notConfirmYet => 'Pas encore';

  @override
  String get unitChangesHint =>
      'Le changement d’unités prend effet immédiatement. Vous devrez peut-être les régler à nouveau après réinstallation.';

  @override
  String get goalSettingsTitle => 'Réglage des objectifs';

  @override
  String get dailyStepGoalField => 'Objectif quotidien de pas (pas)';

  @override
  String get dailyDistanceGoalField => 'Objectif quotidien de distance (km)';

  @override
  String get dailyCalorieGoalField => 'Objectif calorique quotidien (kcal)';

  @override
  String get saveGoals => 'Enregistrer les objectifs';

  @override
  String get viewAccountAddresses =>
      'Voir les adresses de livraison de votre compte';

  @override
  String get loadingProfile => 'Chargement de votre profil…';

  @override
  String get profileSaveExplanation =>
      'Votre photo et votre profil sont enregistrés dans votre compte lorsque vous touchez Enregistrer. Ils permettent de vous identifier dans votre profil et auprès des proches.';

  @override
  String get contactPhoneLabel => 'Téléphone de contact';

  @override
  String get wechatOfficialAccount => 'Compte officiel WeChat';

  @override
  String get addSupportContact => 'Ajouter le contact du support';

  @override
  String get contactPreparationHint =>
      'Préparez le modèle de votre appareil et l’heure du problème avant de contacter le support.';

  @override
  String get supportPrivacyWarning =>
      'N’envoyez pas de codes de vérification, de mots de passe ou de dossiers de santé complets à des comptes non officiels.';

  @override
  String get brandHealthTitle => 'Say Ring Santé';

  @override
  String get accountAndSecurity => 'Compte et sécurité';

  @override
  String get cityNameLabel => 'Nom de la ville';

  @override
  String get cityNameExample => 'Par exemple : Paris';

  @override
  String get visitStoreHint =>
      'Visitez la boutique pour choisir un appareil qui vous convient.';

  @override
  String get selectReportPlan => 'Choisir une formule de rapport';

  @override
  String get reportPaidContentHint =>
      'Les alertes d’anomalies évidentes restent gratuites. Les contenus payants comprennent des synthèses de tendances plus détaillées et des conseils de bien-être au quotidien.';

  @override
  String get wechatPayLabel => 'WeChat Pay';

  @override
  String get alipayLabel => 'Alipay';

  @override
  String get reportPurchaseTerms =>
      'Vérifiez la formule et le prix avant l’achat. L’abonnement santé ne se renouvelle pas automatiquement et les crédits inutilisés ne sont pas reportés après expiration.';

  @override
  String get detailedHealthReport => 'Rapport de santé détaillé';

  @override
  String get reportInsufficientDataHint =>
      'Aucune commande de paiement n’est créée si les données sont insuffisantes. Portez votre bague normalement, synchronisez ses données, puis réessayez.';

  @override
  String get waitingPaymentConfirmation =>
      'En attente de confirmation du paiement';

  @override
  String get paymentReturnRefreshHint =>
      'Après le paiement, revenez sur cette page et actualisez-la. Vos crédits disponibles seront mis à jour une fois le paiement vérifié.';

  @override
  String get reportPurchaseDataMissing =>
      'Les données sont encore insuffisantes ; l’achat n’est donc pas disponible.';

  @override
  String get heartRateUpperLimit => 'Seuil supérieur de fréquence cardiaque';

  @override
  String get systolicUpperLimit => 'Seuil supérieur de pression systolique';

  @override
  String get diastolicUpperLimit => 'Seuil supérieur de pression diastolique';

  @override
  String get temperatureUpperLimit => 'Seuil supérieur de température';

  @override
  String get calibrateOnWatchHint =>
      'Suivez les instructions de votre bague pour terminer l’étalonnage.';

  @override
  String get spotCheckCuffHint =>
      'Il s’agit d’une mesure ponctuelle au repos, à titre indicatif. Pour une mesure plus précise, utilisez un tensiomètre au bras validé.';

  @override
  String get setHealthUpperLimits =>
      'Définir les seuils supérieurs des alertes de santé';

  @override
  String get healthUpperLimitHint =>
      'Recevez une alerte lorsqu’une valeur dépasse le seuil choisi.';

  @override
  String get heartRateAlertLabel => 'Alerte de fréquence cardiaque';

  @override
  String get heartRateAlertHint =>
      'Alerte lorsque la fréquence cardiaque dépasse le seuil défini';

  @override
  String get bloodPressureAlertLabel => 'Alerte de tension artérielle';

  @override
  String get bloodPressureAlertHint =>
      'Alerte lorsque la pression systolique ou diastolique dépasse le seuil défini';

  @override
  String get temperatureAlertLabel => 'Alerte de température';

  @override
  String get temperatureAlertHint =>
      'Alerte lorsque la température dépasse le seuil défini';

  @override
  String get saveHealthAlerts => 'Enregistrer les alertes';

  @override
  String get healthAlertHistory => 'Historique des alertes';

  @override
  String get seekProfessionalCare =>
      'Si vous ressentez un malaise important, consultez rapidement un professionnel de santé.';

  @override
  String get watchHealthReference =>
      'Les mesures de la bague servent de référence pour le suivi quotidien du bien-être.';

  @override
  String get calibrationReferenceHint =>
      'Utilisez une valeur qui vient d’être mesurée avec un appareil professionnel.';

  @override
  String get calibrationWearerHint =>
      'L’étalonnage ne s’applique qu’à la personne qui porte actuellement la bague. Désactivez-le ou recommencez-le si elle change.';

  @override
  String get enableCalibration => 'Activer l’étalonnage';

  @override
  String get calibrationDisabledHint =>
      'La désactivation rétablit le mode de mesure général de la bague.';

  @override
  String get diastolicLowerLabel => 'Pression diastolique (chiffre inférieur)';

  @override
  String get longTermTrendHint =>
      'Les tendances à long terme offrent un contexte plus utile.';

  @override
  String get measurementVariationHint =>
      'Une mesure isolée peut être influencée par le port de la bague, l’activité et l’environnement. En cas de malaise, consultez un professionnel de santé.';

  @override
  String get ecgDetailTitle => 'Détails ECG';

  @override
  String get viewFullReport => 'Voir le rapport complet';

  @override
  String get ecgReferenceHint =>
      'Les résultats ECG servent uniquement de référence pour le bien-être.';

  @override
  String get ecgVariationSafety =>
      'Une mesure isolée est influencée par le port, l’activité et l’environnement et ne remplace pas un diagnostic médical. En cas de malaise, consultez rapidement.';

  @override
  String get ecgBasicOnly =>
      'Seules les données ECG de base ont été reçues pour cette mesure.';

  @override
  String get measurementIndicators => 'Indicateurs de mesure';

  @override
  String get riskIndicatorsMissing =>
      'La bague n’a pas renvoyé d’indicateurs de risque pour cette mesure.';

  @override
  String get riskAnalysisTitle => 'Analyse des risques';

  @override
  String get watchAlgorithmReference =>
      'Les valeurs ci-dessous proviennent de l’algorithme de la bague et servent uniquement de référence pour les tendances de santé.';

  @override
  String get ecgHealthReport => 'Rapport de santé ECG';

  @override
  String get brandedEcgReport => 'Say Ring · Rapport de santé ECG';

  @override
  String get ecgReportSafety =>
      'Remarque : ce rapport utilise les mesures de la bague. Il sert uniquement de référence pour le bien-être et ne remplace pas le diagnostic d’un médecin.';

  @override
  String get installedWatchFaces => 'Styles d’affichage installés';

  @override
  String get switchInstalledWatchFace =>
      'Choisissez parmi les styles d’affichage déjà enregistrés sur votre bague.';

  @override
  String get useSelectedWatchFace => 'Utiliser';

  @override
  String get downloadUseWatchFace => 'Touchez pour télécharger et utiliser';

  @override
  String get photoWatchFaceHint =>
      'Choisissez une photo nette, vérifiez l’aperçu, puis envoyez-la à votre bague.';

  @override
  String get timeDisplayPosition => 'Position de l’heure';

  @override
  String get transferSetWatchFace =>
      'Envoyer et définir comme style d’affichage';

  @override
  String get watchTransferKeepNear =>
      'Gardez la bague près du téléphone pendant le transfert et restez sur cette page.';

  @override
  String get callMediaAudio => 'Audio des appels et des médias';

  @override
  String get useCelsius => 'Utiliser les degrés Celsius';

  @override
  String get sosContactHint =>
      'Lorsque SOS est déclenché sur la bague, la personne choisie ici sera contactée en premier. Choisissez un proche que vous contactez régulièrement.';

  @override
  String get noHealthAssessments =>
      'Aucune évaluation de santé configurable n’est disponible sur cette bague.';

  @override
  String get modelFeaturesVary =>
      'Les fonctions disponibles varient selon le modèle. L’app affiche uniquement celles disponibles pour la bague connectée.';

  @override
  String get assessmentEnabledHint =>
      'Une fois activée, la bague fournit des informations sur les tendances quotidiennes.';

  @override
  String get assessmentSafety =>
      'Les évaluations complémentaires servent de référence pour le bien-être quotidien, pas au diagnostic ni au traitement.';

  @override
  String get autoMonitorIntervalHint =>
      'Une fois activée, la bague effectue les mesures automatiquement à l’intervalle configuré.';

  @override
  String get watchHeartRateAlert => 'Alerte de fréquence cardiaque de la bague';

  @override
  String get sustainedLimitWatchAlert =>
      'La bague vous avertit si la valeur reste au-dessus du seuil.';

  @override
  String get ecgWaveformTitle => 'Tracé ECG';

  @override
  String get ecgWaveformMissing =>
      'Aucun tracé ECG valide n’a été reçu pour cette mesure.';

  @override
  String get ecgElectrodeHint =>
      'Les résultats de fréquence cardiaque et de VFC restent consultables. Gardez le contact avec l’électrode de la bague pendant toute la prochaine mesure.';

  @override
  String get screenAutoTimeHint =>
      'La bague s’adapte automatiquement selon l’heure.';

  @override
  String get raiseWristScreenHint =>
      'L’écran s’allume lorsque vous levez le poignet.';

  @override
  String get watchHighHeartRate => 'Alerte de fréquence cardiaque élevée';

  @override
  String get watchThresholdHint =>
      'La bague vous avertit lorsque le seuil est atteint.';

  @override
  String get watchMeasurementSafety =>
      'Les mesures servent uniquement de référence pour le bien-être, pas au diagnostic ni au traitement.';

  @override
  String get healthDataExplanation => 'À propos des données de santé';

  @override
  String get trendUnavailable =>
      'Les tendances sont temporairement indisponibles.';

  @override
  String get recentData => 'Données récentes';

  @override
  String get trendReferenceOnly =>
      'Les tendances servent uniquement de référence pour le bien-être quotidien.';

  @override
  String get trendVariationSafety =>
      'Les variations ponctuelles et au fil du temps peuvent être influencées par le port, l’activité et l’environnement et ne remplacent pas un diagnostic médical.';

  @override
  String get watchFaceDownloadHint =>
      'Après le téléchargement, le style d’affichage sera envoyé à la bague. Gardez-la près du téléphone et restez sur cette page pendant le transfert.';

  @override
  String get refreshWatchFaces => 'Actualiser les styles d’affichage';

  @override
  String get openTestFlight => 'Ouvrir TestFlight';

  @override
  String get articlesEmpty =>
      'Aucun article n’est encore disponible dans cette catégorie.';

  @override
  String get articlesUnavailable =>
      'Impossible de charger la bibliothèque de santé.';

  @override
  String get articleContentUnavailable =>
      'Le contenu de l’article n’est pas encore disponible.';

  @override
  String get imageUnavailable => 'Impossible de charger l’image.';

  @override
  String get allowNotifications => 'Autoriser les notifications';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get analysisConsentUnavailable =>
      'L’analyse de santé n’est pas encore disponible. Les rapports existants restent consultables.';

  @override
  String get analysisReadAgree =>
      'J’ai lu et j’accepte les informations ci-dessus sur l’analyse de santé.';

  @override
  String get agreeContinue => 'Accepter et continuer';

  @override
  String get notGrantNow => 'Pas maintenant';

  @override
  String get analysisConsentSaved =>
      'Consentement à l’analyse de santé enregistré.';

  @override
  String get withdrawAnalysisConsent =>
      'Retirer le consentement à l’analyse de santé ?';

  @override
  String get withdrawAnalysisExplanation =>
      'Aucun nouveau rapport détaillé ne sera généré. Les rapports existants non remboursés resteront accessibles.';

  @override
  String get confirmWithdraw => 'Confirmer le retrait';

  @override
  String get analysisConsentWithdrawn =>
      'Consentement à l’analyse de santé retiré.';

  @override
  String get consentGrantedHint =>
      'Consentement donné. Vous pouvez le retirer à tout moment.';

  @override
  String get consentNeededHint =>
      'Un consentement distinct est requis avant de générer un rapport détaillé.';

  @override
  String get withdraw => 'Retirer';

  @override
  String get reportHistory => 'Historique des rapports';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get pauseWorkout => 'Mettre en pause';

  @override
  String get resumeWorkout => 'Reprendre l’entraînement';

  @override
  String get finishWorkout => 'Terminer l’entraînement';

  @override
  String get watchDistance => 'Distance de la bague';

  @override
  String get watchSteps => 'Pas de la bague';

  @override
  String get liveHeartRate => 'Fréquence cardiaque actuelle';

  @override
  String get watchCalories => 'Calories de la bague';

  @override
  String get connectForWorkout =>
      'Connectez d’abord votre bague sur la page Appareil. La bague enregistrera l’entraînement.';

  @override
  String latestVersion(String version) {
    return 'Vous utilisez la dernière version : V$version';
  }

  @override
  String workoutPaused(String mode) {
    return '$mode en pause';
  }

  @override
  String workoutInProgress(String mode) {
    return '$mode en cours';
  }

  @override
  String workoutReady(String mode) {
    return 'Prêt à commencer : $mode';
  }

  @override
  String startWorkout(String mode) {
    return 'Commencer : $mode';
  }

  @override
  String finishOtherWorkout(String mode) {
    return 'Terminez d’abord : $mode';
  }

  @override
  String workoutDetails(String mode) {
    return 'Détails : $mode';
  }

  @override
  String stepCount(int count) {
    return '$count pas';
  }

  @override
  String get globalShopPricePending => 'Prix à confirmer';

  @override
  String get globalShopLoadMore => 'Afficher plus';

  @override
  String get globalShopReadOnly =>
      'Consultez les produits ici. Les commandes ne sont pas encore disponibles dans cette région.';

  @override
  String get appName => 'Say Ring';

  @override
  String get searchingNearby => 'Recherche de bagues à proximité';

  @override
  String get noDevices => 'Aucun appareil trouvé';

  @override
  String get selectWatch =>
      'Vérifiez le nom et le signal, puis choisissez votre bague';

  @override
  String get searchingHint =>
      'Recherche en cours. Le signal se met à jour sans déplacer la liste.';

  @override
  String get activateWatch =>
      'Chargez la bague pour l’activer puis placez-la près du téléphone';

  @override
  String get checkWatchConnection =>
      'Si la bague est connectée au Bluetooth de ce téléphone ou d’un autre, déconnectez-la puis relancez la recherche';

  @override
  String get running => 'Course';

  @override
  String get indoorRunning => 'Course en intérieur';

  @override
  String get walking => 'Marche';

  @override
  String get cycling => 'Vélo';

  @override
  String get indoorCycling => 'Vélo en intérieur';

  @override
  String get basketball => 'Basket-ball';

  @override
  String get football => 'Football';

  @override
  String get badminton => 'Badminton';

  @override
  String get swimming => 'Natation';

  @override
  String get jumpRope => 'Corde à sauter';

  @override
  String get yoga => 'Yoga';

  @override
  String get hiking => 'Randonnée';

  @override
  String get mountaineering => 'Alpinisme';

  @override
  String get todayActivity => 'Activité du jour';

  @override
  String get dailyActivityGoalHint =>
      'Progressez vers vos objectifs quotidiens';

  @override
  String metricAnalysis(String metric) {
    return 'Analyse : $metric';
  }

  @override
  String metricAllData(String metric) {
    return 'Toutes les données : $metric';
  }

  @override
  String metricMeasurement(String metric) {
    return 'Mesurer : $metric';
  }

  @override
  String metricCalibration(String metric) {
    return 'Étalonner : $metric';
  }

  @override
  String metricDetails(String metric) {
    return 'Détails : $metric';
  }

  @override
  String get add => 'Ajouter';

  @override
  String get endTime => 'Heure de fin';

  @override
  String get reminderInterval => 'Intervalle de rappel';

  @override
  String get reminderName => 'Nom du rappel';

  @override
  String get repeat => 'Répéter';

  @override
  String get addAlarm => 'Ajouter une alarme';

  @override
  String get alarmTime => 'Heure du rappel';

  @override
  String get enableAlarm => 'Activer l’alarme';

  @override
  String get emergencyContact => 'Contact d’urgence SOS';

  @override
  String get selectEmergencyContact => 'Choisir le contact SOS';

  @override
  String get confirmEmergencyContact => 'Définir comme contact SOS';

  @override
  String get addWorldClock => 'Ajouter une horloge mondiale';

  @override
  String get autoBrightness => 'Luminosité automatique';

  @override
  String get raiseToWake => 'Lever pour activer';

  @override
  String get activeTime => 'Période active';

  @override
  String get saveSettings => 'Enregistrer les paramètres';

  @override
  String get helpFeedback => 'Aide et commentaires';

  @override
  String get issueType => 'Type de problème';

  @override
  String get issueDescription => 'Description';

  @override
  String get describeIssue =>
      'Décrivez le problème et les étapes pour le reproduire';

  @override
  String get contactOptional => 'Coordonnées (facultatif)';

  @override
  String get phoneOrEmail => 'Téléphone ou e-mail';

  @override
  String get call => 'Appeler';

  @override
  String get addContact => 'Ajouter un contact';

  @override
  String get contactName => 'Nom';

  @override
  String get contactPhone => 'Numéro de téléphone';

  @override
  String get cart => 'Panier';

  @override
  String get searchProducts => 'Rechercher des produits';

  @override
  String get selectVariant => 'Choisir une option';

  @override
  String get variant => 'Options';

  @override
  String get buyNow => 'Acheter maintenant';

  @override
  String get cartEmpty => 'Votre panier est vide';

  @override
  String get returnShop => 'Retour à la boutique';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get checkout => 'Passer commande';

  @override
  String get clearCart => 'Vider le panier ?';

  @override
  String get clearCartHint => 'Tous les articles du panier seront retirés.';

  @override
  String get viewOrder => 'Voir la commande';

  @override
  String get confirmOrder => 'Confirmer la commande';

  @override
  String get productInfo => 'Informations du produit';

  @override
  String get orderNote => 'Message';

  @override
  String get noteToSeller => 'Laisser un message au vendeur';

  @override
  String get paymentCheckout => 'Paiement';

  @override
  String get orderTotal => 'Total de la commande';

  @override
  String get selectPayment => 'Choisir le mode de paiement';

  @override
  String get refreshOrder => 'Actualiser la commande';

  @override
  String get viewMyOrders => 'Voir mes commandes';

  @override
  String get backToProduct => 'Retour au produit';

  @override
  String get newAddress => 'Ajouter une adresse';

  @override
  String get recipient => 'Destinataire';

  @override
  String get province => 'État / province';

  @override
  String get district => 'District / comté';

  @override
  String get streetAddress => 'Adresse complète';

  @override
  String get defaultAddress => 'Définir comme adresse par défaut';

  @override
  String get shippingInfo => 'Informations de livraison';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get paymentMethod => 'Mode de paiement';

  @override
  String get refresh => 'Actualiser';

  @override
  String get useWatchFace => 'Utiliser ce style d’affichage ?';

  @override
  String get downloadAndUse => 'Télécharger et utiliser';

  @override
  String get watchFaceFailed => 'Impossible d’appliquer le style d’affichage';

  @override
  String get statusNormal => 'Normal';

  @override
  String get statusRecorded => 'Enregistré';

  @override
  String get statusAttention => 'Vérifier la mesure';

  @override
  String get statusOutOfRange => 'Hors référence';

  @override
  String get statusLow => 'Bas';

  @override
  String get statusHigh => 'Élevé';

  @override
  String get careInviteHint =>
      'Invitez un compte Say Ring par e-mail ou numéro de téléphone international.';

  @override
  String get careSharingHint =>
      'Seules les mesures sélectionnées sont partagées. Vous pouvez arrêter le partage à tout moment.';

  @override
  String get carePending => 'En attente';

  @override
  String get careActive => 'Actif';

  @override
  String get careClosed => 'Terminé';

  @override
  String get accept => 'Accepter';

  @override
  String get decline => 'Refuser';

  @override
  String get stopSharing => 'Arrêter le partage';

  @override
  String get sharedMeasurements => 'Mesures partagées';

  @override
  String get invitationSent => 'Invitation envoyée';

  @override
  String get invalidCareContact =>
      'Saisissez un e-mail ou un numéro de téléphone avec indicatif pays.';

  @override
  String get carePermissionDenied =>
      'Cette mesure n’a pas été partagée avec vous.';

  @override
  String get reload => 'Recharger';

  @override
  String get applyAfterSales => 'Demander une assistance';

  @override
  String get analysisConsent => 'Consentement à l’analyse de santé';

  @override
  String get workoutRecords => 'Historique des activités';

  @override
  String get startTime => 'Heure de début';

  @override
  String get addCare => 'Ajouter un proche';

  @override
  String get confirmReceipt => 'Confirmer la réception';

  @override
  String get personalInfo => 'Informations personnelles';

  @override
  String get deliveryAddresses => 'Adresses de livraison';

  @override
  String get readAgain => 'Relire';

  @override
  String get smsCode => 'Code SMS';

  @override
  String get watchFaceShop => 'Boutique de styles d’affichage';

  @override
  String get selectCity => 'Choisir une ville';

  @override
  String get city => 'Ville';

  @override
  String get confirm => 'Confirmer';

  @override
  String get productDetails => 'Détails du produit';

  @override
  String get clear => 'Vider';

  @override
  String get settings => 'Paramètres';

  @override
  String get goals => 'Objectifs';

  @override
  String get send => 'Envoyer';

  @override
  String get typeMessage => 'Saisissez un message…';

  @override
  String get devicesFound => 'Appareils trouvés';

  @override
  String get connect => 'Connecter';

  @override
  String get searchAgain => 'Rechercher à nouveau';

  @override
  String get searchRecovery =>
      'Gardez la bague près du téléphone. Si elle est connectée au Bluetooth système ou à un autre téléphone, déconnectez-la puis réessayez.';

  @override
  String get deviceName => 'Nom de l’appareil';

  @override
  String get deviceModel => 'Modèle de l’appareil';

  @override
  String get connectionStatus => 'État de connexion';

  @override
  String get firmwareVersion => 'Version du micrologiciel';

  @override
  String get watchBattery => 'Batterie de la bague';

  @override
  String get chargingStatus => 'État de charge';

  @override
  String get messageDetails => 'Détails du message';

  @override
  String get dailySummary => 'Résumé du jour';

  @override
  String get remoteMemberData => 'Données du proche';

  @override
  String get ecgWaveformUnavailable => 'Aucune courbe ECG disponible';

  @override
  String get orderDetails => 'Détails de la commande';

  @override
  String get viewShipping => 'Suivre la livraison';

  @override
  String get measureAgain => 'Mesurer à nouveau';

  @override
  String get checkPaymentStatus => 'Vérifier le paiement';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get confirmDeleteAccountTitle => 'Supprimer votre compte ?';

  @override
  String get deleteAccountHint =>
      'Vous serez déconnecté après la suppression de votre compte et des données associées.';

  @override
  String get confirmDelete => 'Confirmer la suppression';

  @override
  String get exit => 'Quitter';

  @override
  String get nickname => 'Pseudonyme';

  @override
  String get gender => 'Genre';

  @override
  String get birthDate => 'Date de naissance';

  @override
  String get heightCm => 'Taille (cm)';

  @override
  String get weightKg => 'Poids (kg)';

  @override
  String get choose => 'Sélectionner';

  @override
  String get connectWatchToUse =>
      'Connectez une bague pour utiliser cette fonction';

  @override
  String get selectPhoto => 'Choisir une photo';

  @override
  String get saved => 'Enregistré';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get notificationsOff => 'Les notifications système sont désactivées';

  @override
  String get privacyAgreement => 'Politique de confidentialité';

  @override
  String get appPermissions => 'Autorisations de l’application';

  @override
  String get openSystemSettings =>
      'Ouvrir les paramètres système de l’application';

  @override
  String get monitoringHint =>
      'Les réglages disponibles pour cette bague s’affichent après la connexion.';

  @override
  String get previewUnavailable => 'Aperçu indisponible';

  @override
  String get distance => 'Distance';

  @override
  String get calories => 'Calories';

  @override
  String get healthProfile => 'Profil de santé';

  @override
  String get photoWatchFace => 'Affichage photo';

  @override
  String get cameraRemote => 'Télécommande photo';

  @override
  String get phoneCalls => 'Appels';

  @override
  String get contacts => 'Contacts';

  @override
  String get notifications => 'Notifications';

  @override
  String get alarms => 'Alarmes';

  @override
  String get weather => 'Météo';

  @override
  String get worldClock => 'Horloge mondiale';

  @override
  String get healthReminders => 'Rappels bien-être';

  @override
  String get healthMonitoring => 'Suivi de santé';

  @override
  String get healthAssessment => 'Bilan bien-être';

  @override
  String get screenDisplay => 'Affichage';

  @override
  String get scanning => 'Recherche…';

  @override
  String get connecting => 'Connexion…';

  @override
  String get waitingConfirmation => 'En attente de confirmation';

  @override
  String get syncing => 'Synchronisation…';

  @override
  String get measuring => 'Mesure…';

  @override
  String get needsAttention => 'Action requise';

  @override
  String get tapToOpen => 'Touchez pour ouvrir';

  @override
  String get deviceInfoHint => 'Voir les informations de l’appareil';

  @override
  String get connectionInstructions =>
      '1. Activez le Bluetooth et l’accès aux appareils à proximité.\n2. Chargez la bague et placez-la près du téléphone.\n3. Lancez la recherche et sélectionnez votre bague.\n4. Confirmez sur la bague si nécessaire.';

  @override
  String get syncNearbyHint =>
      'Gardez la bague chargée et près du téléphone pendant la connexion ou la synchronisation.';

  @override
  String get invalidCode => 'Vérifiez le code et réessayez';

  @override
  String get codeExpired => 'Ce code a expiré. Demandez-en un nouveau.';

  @override
  String get tooManyAttempts => 'Trop de tentatives. Patientez puis réessayez.';

  @override
  String get readTerms =>
      'Lisez les conditions et la politique de confidentialité pour continuer';

  @override
  String verificationSentTo(String contact) {
    return 'Code envoyé à $contact';
  }

  @override
  String get addSmartDevice => 'Ajouter un appareil connecté';

  @override
  String get watchNearbyHint =>
      'Activez le Bluetooth et gardez la bague près du téléphone';

  @override
  String get startSearch => 'Rechercher des appareils';

  @override
  String get readingData => 'Lecture des données…';

  @override
  String get readingCapabilities => 'Vérification des fonctions de la bague…';

  @override
  String get capabilitiesHint =>
      'Seules les fonctions disponibles sur cette bague s’afficheront';

  @override
  String get capabilitiesFailed =>
      'Impossible de lire les fonctions de cette bague';

  @override
  String get keepWatchNear => 'Gardez la bague près du téléphone et réessayez';

  @override
  String get personalizeWatch => 'Affichage et personnalisation';

  @override
  String get signInCloudHint =>
      'Connectez-vous pour les services de santé en ligne';

  @override
  String get aiQuestion => 'Demander à l’IA';

  @override
  String get aiQuestionHint =>
      'Posez vos questions de bien-être à l’assistant IA';

  @override
  String get language => 'Langue';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S’inscrire';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get email => 'E-mail';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get countryRegion => 'Pays ou région';

  @override
  String get password => 'Mot de passe';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get verificationCode => 'Code de vérification';

  @override
  String get sendCode => 'Envoyer le code';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get resetPassword => 'Réinitialiser le mot de passe';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get continueAction => 'Continuer';

  @override
  String get back => 'Retour';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get retry => 'Réessayer';

  @override
  String get loading => 'Chargement…';

  @override
  String get pleaseWait => 'Veuillez patienter…';

  @override
  String get emailOrPhone => 'E-mail ou téléphone';

  @override
  String get enterEmail => 'Saisissez votre adresse e-mail';

  @override
  String get enterPhone => 'Saisissez votre numéro de téléphone';

  @override
  String get enterPassword => 'Saisissez votre mot de passe';

  @override
  String get passwordRequirement =>
      'Au moins 8 caractères. Jusqu’à 72 lettres anglaises ou chiffres ; moins avec d’autres caractères.';

  @override
  String get passwordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get invalidEmail => 'Saisissez une adresse e-mail valide';

  @override
  String get invalidPhone => 'Vérifiez l’indicatif et le numéro';

  @override
  String get codeSent => 'Code envoyé. Consultez vos messages.';

  @override
  String get codeRequired => 'Saisissez le code de vérification';

  @override
  String get consentRequired =>
      'Veuillez lire et accepter les conditions et la politique de confidentialité';

  @override
  String get agreeToTerms => 'J’ai lu et j’accepte';

  @override
  String get termsOfService => 'Conditions d’utilisation';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get registrationUnavailable =>
      'L’inscription est temporairement indisponible. Réessayez plus tard.';

  @override
  String get loginFailed =>
      'Connexion impossible. Vérifiez vos informations et réessayez.';

  @override
  String get accountAlreadyExists => 'Ce compte existe déjà. Connectez-vous.';

  @override
  String get networkUnavailable => 'Vérifiez votre connexion et réessayez';

  @override
  String get serviceUnavailable =>
      'Cette fonction est temporairement indisponible. Réessayez plus tard.';

  @override
  String get accountCreated => 'Votre compte est prêt';

  @override
  String get passwordReset => 'Mot de passe mis à jour';

  @override
  String get haveAccount => 'Vous avez déjà un compte ?';

  @override
  String get noAccount => 'Nouveau sur Say Ring ?';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get selectCountry => 'Sélectionnez un pays ou une région';

  @override
  String get registrationMethod => 'S’inscrire avec';

  @override
  String get changeLanguageFailed =>
      'Impossible d’enregistrer la langue. Réessayez.';

  @override
  String get health => 'Santé';

  @override
  String get device => 'Appareil';

  @override
  String get profile => 'Moi';

  @override
  String get healthData => 'Données de santé';

  @override
  String get allData => 'Toutes les données';

  @override
  String get healthRecords => 'Historique de santé';

  @override
  String get workoutsAndRecords => 'Activités et historique';

  @override
  String get healthDisclaimer =>
      'Les mesures sont indicatives. Consultez un professionnel de santé si vous vous sentez mal.';

  @override
  String get healthSafetyAdvice =>
      'Reposez-vous puis mesurez à nouveau. En cas de malaise, consultez un professionnel de santé.';

  @override
  String get defaultUser => 'Utilisateur Say Ring';

  @override
  String get dailyGreeting => 'Prenez soin de vous aujourd’hui';

  @override
  String get messages => 'Messages';

  @override
  String get aiAssistant => 'Assistant bien-être IA';

  @override
  String get aiAssistantIntro => 'Posez-moi une question sur votre bien-être.';

  @override
  String get askNow => 'Poser une question';

  @override
  String get remoteCare => 'Suivi des proches';

  @override
  String get healthLibrary => 'Bibliothèque santé';

  @override
  String get healthAlerts => 'Alertes de santé';

  @override
  String get shop => 'Boutique';

  @override
  String get connectWatch => 'Connecter une bague';

  @override
  String get addDevice => 'Ajouter un appareil';

  @override
  String get connectWatchForData =>
      'Connectez votre bague pour voir les données de santé prises en charge';

  @override
  String get noHealthData => 'Aucune donnée de santé à afficher';

  @override
  String get noData => 'Aucune donnée';

  @override
  String get connected => 'Connecté';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get online => 'En ligne';

  @override
  String get syncData => 'Synchroniser les données';

  @override
  String get syncComplete => 'Données synchronisées';

  @override
  String get syncFailedTryAgain =>
      'Échec de la synchronisation. Gardez la bague près du téléphone et réessayez.';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get findWatch => 'Trouver la bague';

  @override
  String get watchFaces => 'Styles d’affichage';

  @override
  String get deviceFeatures => 'Fonctions de l’appareil';

  @override
  String get aboutDevice => 'À propos de l’appareil';

  @override
  String get connectionHelp => 'Aide à la connexion';

  @override
  String get searchNearbyWatch =>
      'Recherchez et connectez une Say Ring à proximité';

  @override
  String get useWatch => 'Utilisez cette fonction sur votre bague';

  @override
  String get myOrders => 'Mes commandes';

  @override
  String get all => 'Tout';

  @override
  String get awaitingPayment => 'À payer';

  @override
  String get awaitingShipment => 'À expédier';

  @override
  String get awaitingDelivery => 'À recevoir';

  @override
  String get afterSales => 'Retours et assistance';

  @override
  String get careMembers => 'Proches suivis';

  @override
  String get unitSettings => 'Unités';

  @override
  String get unitSettingsHint =>
      'Choisissez les unités de distance, de température, etc.';

  @override
  String get myServices => 'Mes services';

  @override
  String get accountSettings => 'Paramètres du compte';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get permissions => 'Autorisations';

  @override
  String get feedback => 'Commentaires';

  @override
  String get customerService => 'Assistance';

  @override
  String get aboutApp => 'À propos de Say Ring';

  @override
  String get security => 'Sécurité du compte';

  @override
  String get goToSettings => 'Ouvrir les paramètres';

  @override
  String get close => 'Fermer';

  @override
  String get view => 'Voir';

  @override
  String get checkUpdates => 'Rechercher des mises à jour';

  @override
  String get onlineUpdate => 'Mise à jour';

  @override
  String get updateRequired => 'Mettez à jour pour continuer';

  @override
  String get updateReady => 'Une mise à jour est disponible';

  @override
  String get preparingUpdate => 'Préparation d’une mise à jour sécurisée…';

  @override
  String get openingUpdate => 'Ouverture de la page de mise à jour…';

  @override
  String get updateAppStore => 'Mettre à jour dans l’App Store';

  @override
  String get updateStore => 'Mettre à jour dans la boutique d’applications';

  @override
  String get downloadAndInstall => 'Télécharger et installer en sécurité';

  @override
  String get gettingReady => 'Préparation…';

  @override
  String get enableNotifications => 'Activer les notifications Say Ring';

  @override
  String get notificationExplanation =>
      'Recevez des alertes de santé et des invitations. Les valeurs de santé ne s’affichent pas sur l’écran verrouillé. Vous pouvez désactiver les notifications dans les paramètres système.';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get enable => 'Activer';

  @override
  String get newCareRequest => 'Nouvelle demande de suivi';

  @override
  String get dismissHealthAlert => 'Fermer l’alerte de santé';

  @override
  String get dismissCareAlert => 'Fermer le rappel de suivi';

  @override
  String get bloodPressure => 'Pression artérielle';

  @override
  String get heartRate => 'Fréquence cardiaque';

  @override
  String get bloodOxygen => 'Oxygène sanguin';

  @override
  String get bloodGlucose => 'Glycémie';

  @override
  String get bodyTemperature => 'Température cutanée';

  @override
  String get ecg => 'ECG';

  @override
  String get hrv => 'VFC';

  @override
  String get stress => 'Stress';

  @override
  String get bodyComposition => 'Composition corporelle';

  @override
  String get bloodComposition => 'Composition sanguine';

  @override
  String get sleep => 'Sommeil';

  @override
  String get steps => 'Pas';

  @override
  String get workouts => 'Activités';

  @override
  String welcome(String name) {
    return 'Bonjour, $name';
  }

  @override
  String resendCode(int seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String memberId(String id) {
    return 'Identifiant : $id';
  }

  @override
  String unreadMessages(int count) {
    return 'Messages, $count non lus';
  }

  @override
  String recordCount(int count) {
    return '$count relevés';
  }

  @override
  String memberCount(int count) {
    return '$count membres';
  }

  @override
  String versionBuild(String version, int build) {
    return 'V$version · Build $build';
  }

  @override
  String get globalShopBrowseNotice =>
      'Vous pouvez continuer à parcourir la boutique. Les commandes seront disponibles lorsque la livraison et le paiement le seront pour votre marché.';

  @override
  String get shopAccount => 'Compte boutique';

  @override
  String get addToCart => 'Ajouter au panier';

  @override
  String get addedToCart => 'Ajouté au panier';

  @override
  String get quantity => 'Quantité';

  @override
  String get inStock => 'En stock';

  @override
  String get outOfStock => 'Épuisé ou indisponible';

  @override
  String get favorites => 'Favoris';

  @override
  String get coupons => 'Coupons';

  @override
  String get points => 'Points';

  @override
  String get helpCenter => 'Centre d’aide';

  @override
  String get chooseDeliveryAddress => 'Choisir une adresse de livraison';

  @override
  String get editAddress => 'Modifier l’adresse';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteAddressPrompt => 'Supprimer cette adresse ?';

  @override
  String get postalCode => 'Code postal';

  @override
  String get itemsSubtotal => 'Sous-total des articles';

  @override
  String get discount => 'Remise';

  @override
  String get shippingFee => 'Livraison';

  @override
  String get amountDue => 'Montant à payer';

  @override
  String get placeOrder => 'Passer la commande';

  @override
  String get orderPlaced => 'Commande passée';

  @override
  String get orderSubmissionUncertain =>
      'Le résultat de la commande n’est pas confirmé. Vérifiez Mes commandes avant de réessayer.';

  @override
  String get availableCoupons => 'Coupons disponibles';

  @override
  String get ownedCoupons => 'Mes coupons';

  @override
  String get couponCode => 'Code du coupon';

  @override
  String get redeem => 'Utiliser';

  @override
  String get claim => 'Obtenir';

  @override
  String get claimed => 'Obtenu';

  @override
  String get pointsBalance => 'Solde de points';

  @override
  String get pointsUnavailable => 'Solde pas encore disponible';

  @override
  String get marketUnavailable =>
      'Les commandes ne sont pas encore disponibles pour le marché de livraison sélectionné.';

  @override
  String get paymentUnavailable =>
      'Le paiement n’est pas disponible dans l’application pour le moment. Votre panier et vos commandes existantes restent accessibles.';

  @override
  String get orderNumber => 'Commande';

  @override
  String get orderDate => 'Créée le';

  @override
  String get cancelOrder => 'Annuler la commande';

  @override
  String get cancelOrderPrompt => 'Annuler cette commande non payée ?';

  @override
  String get refundOnly => 'Remboursement uniquement';

  @override
  String get returnRefund => 'Retour et remboursement';

  @override
  String get exchange => 'Échange';

  @override
  String get submitRequest => 'Envoyer la demande';

  @override
  String get requestSubmitted => 'Demande envoyée';

  @override
  String get writeReview => 'Rédiger un avis';

  @override
  String get submitReview => 'Envoyer l’avis';

  @override
  String get defaultVariant => 'Option par défaut';

  @override
  String selectedItems(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get signInToShopHint =>
      'Connectez-vous pour gérer votre panier, vos adresses et vos commandes.';

  @override
  String get checkoutPriceChanged =>
      'Le total a changé. Vérifiez le montant actualisé avant de continuer.';

  @override
  String get shopHelpIntro =>
      'Les options de commande, de livraison et d’après-vente dépendent des services disponibles sur votre marché.';

  @override
  String get shopHelpOrdering => 'Pourquoi ne puis-je pas commander ?';

  @override
  String get shopHelpOrderingAnswer =>
      'La commande est activée uniquement lorsque les services de livraison et de marché sont disponibles. Vous pouvez conserver les produits dans votre panier et réessayer plus tard.';

  @override
  String get shopHelpPayment => 'Comment le paiement est-il confirmé ?';

  @override
  String get shopHelpPaymentAnswer =>
      'Une commande est marquée comme payée uniquement après confirmation du prestataire de paiement. Ne passez pas une autre commande pendant la confirmation.';

  @override
  String get shopHelpAfterSales =>
      'Comment demander une assistance après-vente ?';

  @override
  String get shopHelpAfterSalesAnswer =>
      'Ouvrez une commande éligible, choisissez Demander de l’aide, vérifiez le montant du remboursement et indiquez votre motif.';

  @override
  String get noOrders => 'Aucune commande';

  @override
  String get noFavorites => 'Aucun favori';

  @override
  String get noCoupons => 'Aucun coupon disponible';

  @override
  String get selectItemsToContinue =>
      'Sélectionnez au moins un article disponible pour continuer.';

  @override
  String get noCoupon => 'Ne pas utiliser de coupon';

  @override
  String get pointsToUse => 'Valeur des points à utiliser';

  @override
  String get refreshOrderTotal => 'Actualiser le total';

  @override
  String get chooseAddressForTotal =>
      'Choisissez une adresse pour obtenir le total actualisé.';

  @override
  String get requiredField => 'Ce champ est obligatoire.';

  @override
  String get invalidInternationalPhone =>
      'Saisissez un numéro valide avec l’indicatif du pays.';

  @override
  String get invalidCouponCode =>
      'Saisissez un code valide de 4 à 32 lettres, chiffres, tirets ou traits de soulignement.';

  @override
  String get unavailable => 'Indisponible';

  @override
  String get orderItemsUnavailable =>
      'Les articles ne sont pas disponibles pour cette ancienne commande.';

  @override
  String get orderCompleted => 'Terminée';

  @override
  String get orderCancelled => 'Annulée';

  @override
  String get orderRefunded => 'Remboursée';

  @override
  String get orderStatusPending => 'En traitement';

  @override
  String get legacyOrderReadOnly =>
      'Cette ancienne commande peut être consultée ici. Contactez l’assistance pour la modifier.';

  @override
  String get returnLogistics => 'Expédition du retour';

  @override
  String get carrier => 'Transporteur';

  @override
  String get trackingNumber => 'Numéro de suivi';

  @override
  String get noShippingUpdates => 'Aucune mise à jour de livraison';

  @override
  String get waitingForReturn => 'En attente du retour';

  @override
  String get requestRejected => 'Demande refusée';

  @override
  String get requestProcessing => 'Demande en cours';

  @override
  String get afterSalesUnavailable =>
      'Aucun article de cette commande n’est éligible à l’assistance après-vente.';

  @override
  String get previewRequest => 'Vérifier le montant de la demande';

  @override
  String get problemPhotos => 'Photos du problème';

  @override
  String get afterSalePhotoHint =>
      'Facultatif. Jusqu’à 9 images JPG, PNG ou WebP de 10 Mo maximum chacune.';

  @override
  String get addProblemPhotos => 'Ajouter des photos';

  @override
  String get chooseFromGallery => 'Choisir dans la galerie';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get photoUploading => 'Téléversement…';

  @override
  String get photoUploaded => 'Téléversée';

  @override
  String get photoUploadFailed =>
      'Échec du téléversement. Réessayez ou supprimez la photo.';

  @override
  String get photoServiceUnavailable =>
      'Impossible d’ajouter des photos pour le moment. Vous pouvez envoyer une description écrite.';

  @override
  String get removePhoto => 'Supprimer la photo';

  @override
  String get photoTooLarge => 'Chaque photo doit faire au maximum 10 Mo.';

  @override
  String get photoFormatUnsupported => 'Choisissez une image JPG, PNG ou WebP.';

  @override
  String get photoReadFailed => 'La photo n’a pas pu être chargée. Réessayez.';

  @override
  String get afterSaleSubmissionUncertain =>
      'Le résultat n’est pas confirmé. Vérifiez la commande ou renvoyez la même demande.';

  @override
  String get requestDetails => 'Détails de la demande';

  @override
  String get afterSaleItems => 'Articles de cette demande';

  @override
  String get afterSaleItemsUnavailable =>
      'Les détails des articles ne sont pas disponibles pour cette demande.';

  @override
  String get refundProgress => 'Suivi du remboursement';

  @override
  String get refundResultPending =>
      'Le résultat du remboursement est en cours de confirmation.';

  @override
  String get afterSaleItem => 'Article après-vente';

  @override
  String get shareProduct => 'Partager le produit';

  @override
  String get customerReviews => 'Avis clients';

  @override
  String stockCount(int count) {
    return '$count en stock';
  }
}
