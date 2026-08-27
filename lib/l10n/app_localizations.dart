import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
  ];

  /// The app title
  ///
  /// In en, this message translates to:
  /// **'Vanshavali'**
  String get appTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Vanshavali'**
  String get welcomeMessage;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with your roots, discover your lineage'**
  String get welcomeSubtitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @sendMagicLink.
  ///
  /// In en, this message translates to:
  /// **'Send Magic Link'**
  String get sendMagicLink;

  /// No description provided for @magicLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Magic link sent! Check your email.'**
  String get magicLinkSent;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// No description provided for @emailPassword.
  ///
  /// In en, this message translates to:
  /// **'Email & Password'**
  String get emailPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @firstNameGujarati.
  ///
  /// In en, this message translates to:
  /// **'First Name (Gujarati)'**
  String get firstNameGujarati;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @lastNameGujarati.
  ///
  /// In en, this message translates to:
  /// **'Last Name (Gujarati)'**
  String get lastNameGujarati;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @isAlive.
  ///
  /// In en, this message translates to:
  /// **'Living'**
  String get isAlive;

  /// No description provided for @deceased.
  ///
  /// In en, this message translates to:
  /// **'Deceased'**
  String get deceased;

  /// No description provided for @villageOrigin.
  ///
  /// In en, this message translates to:
  /// **'Village of Origin'**
  String get villageOrigin;

  /// No description provided for @currentCity.
  ///
  /// In en, this message translates to:
  /// **'Current City'**
  String get currentCity;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupation;

  /// No description provided for @medicalInfo.
  ///
  /// In en, this message translates to:
  /// **'Medical Information'**
  String get medicalInfo;

  /// No description provided for @familyTree.
  ///
  /// In en, this message translates to:
  /// **'Family Tree'**
  String get familyTree;

  /// No description provided for @myFamily.
  ///
  /// In en, this message translates to:
  /// **'My Family'**
  String get myFamily;

  /// No description provided for @father.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get father;

  /// No description provided for @mother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get mother;

  /// No description provided for @spouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get spouse;

  /// No description provided for @spouses.
  ///
  /// In en, this message translates to:
  /// **'Spouses'**
  String get spouses;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// No description provided for @siblings.
  ///
  /// In en, this message translates to:
  /// **'Siblings'**
  String get siblings;

  /// No description provided for @addFather.
  ///
  /// In en, this message translates to:
  /// **'Add Father'**
  String get addFather;

  /// No description provided for @addMother.
  ///
  /// In en, this message translates to:
  /// **'Add Mother'**
  String get addMother;

  /// No description provided for @addSpouse.
  ///
  /// In en, this message translates to:
  /// **'Add Spouse'**
  String get addSpouse;

  /// No description provided for @addChild.
  ///
  /// In en, this message translates to:
  /// **'Add Child'**
  String get addChild;

  /// No description provided for @addSibling.
  ///
  /// In en, this message translates to:
  /// **'Add Sibling'**
  String get addSibling;

  /// No description provided for @addFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Add Family Member'**
  String get addFamilyMember;

  /// No description provided for @linkExisting.
  ///
  /// In en, this message translates to:
  /// **'Link Existing Member'**
  String get linkExisting;

  /// No description provided for @createNew.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createNew;

  /// No description provided for @searchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search Members'**
  String get searchMembers;

  /// No description provided for @inviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get inviteMember;

  /// No description provided for @inviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent!'**
  String get inviteSent;

  /// No description provided for @claimProfile.
  ///
  /// In en, this message translates to:
  /// **'Claim Profile'**
  String get claimProfile;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get viewProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @gujarati.
  ///
  /// In en, this message translates to:
  /// **'ગુજરાતી'**
  String get gujarati;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @syncData.
  ///
  /// In en, this message translates to:
  /// **'Sync Data'**
  String get syncData;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String lastSynced(String time);

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternet;

  /// No description provided for @dataWillSync.
  ///
  /// In en, this message translates to:
  /// **'Your changes will sync when online'**
  String get dataWillSync;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeProfile;

  /// No description provided for @profileCompleted.
  ///
  /// In en, this message translates to:
  /// **'Profile completed successfully!'**
  String get profileCompleted;

  /// No description provided for @translateToGujarati.
  ///
  /// In en, this message translates to:
  /// **'Translate to Gujarati'**
  String get translateToGujarati;

  /// No description provided for @noFamilyMembers.
  ///
  /// In en, this message translates to:
  /// **'No family members added yet'**
  String get noFamilyMembers;

  /// No description provided for @tapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add family members'**
  String get tapToAdd;

  /// No description provided for @relationshipWith.
  ///
  /// In en, this message translates to:
  /// **'Relationship with {name}'**
  String relationshipWith(String name);

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete?'**
  String get confirmDelete;

  /// No description provided for @deleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get deleteWarning;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copyInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Invite Message'**
  String get copyInviteLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied to clipboard'**
  String get linkCopied;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About Vanshavali'**
  String get aboutApp;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pendingInvites.
  ///
  /// In en, this message translates to:
  /// **'Pending Invites'**
  String get pendingInvites;

  /// No description provided for @acceptInvite.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptInvite;

  /// No description provided for @declineInvite.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineInvite;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get selectGender;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Discover Your Roots'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Explore your family history and connect generations'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Build Your Tree'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Add family members and create visual connections'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Stay Connected'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Invite relatives and grow your family network'**
  String get onboardingDesc3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In en, this message translates to:
  /// **'Your Privacy'**
  String get onboardingTitle4;

  /// No description provided for @onboardingDesc4.
  ///
  /// In en, this message translates to:
  /// **'Your family details are visible to other logged-in members of this app and stored securely with Supabase. You can review this anytime in Settings.'**
  String get onboardingDesc4;

  /// No description provided for @privacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Privacy Notice'**
  String get privacyNotice;

  /// No description provided for @privacyNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Vanshavali stores your family tree data (names, relationships, and any details you add) with Supabase, our hosting provider. Once you\'re logged in, other members of this app\'s community can view the shared family tree. Only you can edit your own profile, or an unclaimed relative\'s profile until they claim it themselves.'**
  String get privacyNoticeBody;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @basicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInformation;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get additionalDetails;

  /// No description provided for @relationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationship;

  /// No description provided for @addMethod.
  ///
  /// In en, this message translates to:
  /// **'Add Method'**
  String get addMethod;

  /// No description provided for @pleaseSelectRelationship.
  ///
  /// In en, this message translates to:
  /// **'Please select a relationship'**
  String get pleaseSelectRelationship;

  /// No description provided for @pleaseSelectGender.
  ///
  /// In en, this message translates to:
  /// **'Please select a gender'**
  String get pleaseSelectGender;

  /// No description provided for @completeProfileFirst.
  ///
  /// In en, this message translates to:
  /// **'Please complete your profile first'**
  String get completeProfileFirst;

  /// No description provided for @alreadyExists.
  ///
  /// In en, this message translates to:
  /// **'{relation} already exists. Edit the existing one instead.'**
  String alreadyExists(String relation);

  /// No description provided for @ancestryCycleBlocked.
  ///
  /// In en, this message translates to:
  /// **'{name} can\'t be set as this relation — they\'re already a descendant, and this would create a loop in the family tree.'**
  String ancestryCycleBlocked(String name);

  /// No description provided for @confirmAddMemberTarget.
  ///
  /// In en, this message translates to:
  /// **'Add \"{name}\" as {ownerName}\'s {relation}?'**
  String confirmAddMemberTarget(String name, String ownerName, String relation);

  /// No description provided for @confirmAddMemberSelf.
  ///
  /// In en, this message translates to:
  /// **'Add \"{name}\" as your {relation}?'**
  String confirmAddMemberSelf(String name, String relation);

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @familyMemberAdded.
  ///
  /// In en, this message translates to:
  /// **'Family member added successfully'**
  String get familyMemberAdded;

  /// No description provided for @familyMemberAddedPartial.
  ///
  /// In en, this message translates to:
  /// **'Family member added, but linking some existing children to them failed — please check and try again'**
  String get familyMemberAddedPartial;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching members found'**
  String get noResultsFound;

  /// No description provided for @whoIsThe.
  ///
  /// In en, this message translates to:
  /// **'Who is the {relation}?'**
  String whoIsThe(String relation);

  /// No description provided for @selectOtherParent.
  ///
  /// In en, this message translates to:
  /// **'Select the other parent of this child.'**
  String get selectOtherParent;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @unclaimed.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed'**
  String get unclaimed;

  /// No description provided for @addRelation.
  ///
  /// In en, this message translates to:
  /// **'Add {relation}'**
  String addRelation(String relation);

  /// No description provided for @someoneElse.
  ///
  /// In en, this message translates to:
  /// **'Someone else'**
  String get someoneElse;

  /// No description provided for @createNewProfile.
  ///
  /// In en, this message translates to:
  /// **'Create a new profile'**
  String get createNewProfile;

  /// No description provided for @newRelation.
  ///
  /// In en, this message translates to:
  /// **'New {relation}'**
  String newRelation(String relation);

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First Name *'**
  String get firstNameRequired;

  /// No description provided for @lastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last Name *'**
  String get lastNameRequired;

  /// No description provided for @enterBothNames.
  ///
  /// In en, this message translates to:
  /// **'Please enter both first and last name'**
  String get enterBothNames;

  /// No description provided for @skipOtherParent.
  ///
  /// In en, this message translates to:
  /// **'Skip — Don\'t set other parent'**
  String get skipOtherParent;

  /// No description provided for @verifiedMember.
  ///
  /// In en, this message translates to:
  /// **'Verified Member'**
  String get verifiedMember;

  /// No description provided for @unclaimedProfile.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed Profile'**
  String get unclaimedProfile;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @inviteDescription.
  ///
  /// In en, this message translates to:
  /// **'This profile hasn\'t been claimed yet. Share the invite code below so they can join and manage their own profile.'**
  String get inviteDescription;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get deleteProfile;

  /// No description provided for @confirmDeleteMember.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}\'s profile? This action cannot be undone.'**
  String confirmDeleteMember(String name);

  /// No description provided for @memberDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} has been deleted.'**
  String memberDeleted(String name);

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete profile: {error}'**
  String failedToDelete(String error);

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMessage(String error);

  /// No description provided for @familyRelations.
  ///
  /// In en, this message translates to:
  /// **'Family Relations'**
  String get familyRelations;

  /// No description provided for @centerOnMe.
  ///
  /// In en, this message translates to:
  /// **'Center on me'**
  String get centerOnMe;

  /// No description provided for @centerOnMember.
  ///
  /// In en, this message translates to:
  /// **'Center on this member'**
  String get centerOnMember;

  /// No description provided for @addRelativeForYourself.
  ///
  /// In en, this message translates to:
  /// **'Add a relative for yourself'**
  String get addRelativeForYourself;

  /// No description provided for @addRelativeFor.
  ///
  /// In en, this message translates to:
  /// **'Add a relative for {name}'**
  String addRelativeFor(String name);

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @fullSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'Full sync complete'**
  String get fullSyncComplete;

  /// No description provided for @fullSync.
  ///
  /// In en, this message translates to:
  /// **'Full Sync'**
  String get fullSync;

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get confirmLogout;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @defaultView.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get defaultView;

  /// No description provided for @pedigreeView.
  ///
  /// In en, this message translates to:
  /// **'Pedigree'**
  String get pedigreeView;

  /// No description provided for @editGujaratiSpelling.
  ///
  /// In en, this message translates to:
  /// **'Edit Gujarati Spelling'**
  String get editGujaratiSpelling;

  /// No description provided for @autoTranslation.
  ///
  /// In en, this message translates to:
  /// **'Auto Translation'**
  String get autoTranslation;

  /// No description provided for @transliteration.
  ///
  /// In en, this message translates to:
  /// **'Transliteration'**
  String get transliteration;

  /// No description provided for @typeNameInEnglish.
  ///
  /// In en, this message translates to:
  /// **'Type the name in English'**
  String get typeNameInEnglish;

  /// No description provided for @gujaratiSpellingOptions.
  ///
  /// In en, this message translates to:
  /// **'Tap a Gujarati spelling'**
  String get gujaratiSpellingOptions;

  /// No description provided for @noSpellingSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions — type the spelling below'**
  String get noSpellingSuggestions;

  /// No description provided for @typeManually.
  ///
  /// In en, this message translates to:
  /// **'Type manually in Gujarati'**
  String get typeManually;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @noEnglishText.
  ///
  /// In en, this message translates to:
  /// **'Enter the English name first'**
  String get noEnglishText;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a password reset link.'**
  String get resetPasswordDesc;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent! Check your email.'**
  String get resetLinkSent;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This feature is coming soon.'**
  String get featureComingSoon;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get inviteCode;

  /// No description provided for @inviteCodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Share this code with the person. They can enter it during sign up to claim this profile.'**
  String get inviteCodeDesc;

  /// No description provided for @enterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Have an invite code?'**
  String get enterInviteCode;

  /// No description provided for @enterInviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-character code'**
  String get enterInviteCodeHint;

  /// No description provided for @claimWithCode.
  ///
  /// In en, this message translates to:
  /// **'Claim Profile'**
  String get claimWithCode;

  /// No description provided for @invalidInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired invite code'**
  String get invalidInviteCode;

  /// No description provided for @profileClaimed.
  ///
  /// In en, this message translates to:
  /// **'Profile claimed successfully!'**
  String get profileClaimed;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied'**
  String get codeCopied;

  /// No description provided for @generatingCode.
  ///
  /// In en, this message translates to:
  /// **'Generating code...'**
  String get generatingCode;

  /// No description provided for @orUseInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Or enter an invite code'**
  String get orUseInviteCode;

  /// No description provided for @scanInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Scan invite code'**
  String get scanInviteCode;

  /// No description provided for @scanQrInstruction.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at the invite QR code'**
  String get scanQrInstruction;

  /// No description provided for @cameraPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to scan. You can still enter the code by hand.'**
  String get cameraPermissionNeeded;

  /// No description provided for @scanInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'No valid 6-character invite code found in that QR code.'**
  String get scanInvalidCode;

  /// No description provided for @inviteQrCode.
  ///
  /// In en, this message translates to:
  /// **'Invite QR code'**
  String get inviteQrCode;

  /// No description provided for @enterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter code manually'**
  String get enterManually;

  /// No description provided for @linkChildrenToSpouse.
  ///
  /// In en, this message translates to:
  /// **'Link children to spouse?'**
  String get linkChildrenToSpouse;

  /// No description provided for @linkChildrenToSpouseDesc.
  ///
  /// In en, this message translates to:
  /// **'These children don\'t have the other parent set. Would you like to link them to the new spouse?'**
  String get linkChildrenToSpouseDesc;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get zoomOut;

  /// No description provided for @resetView.
  ///
  /// In en, this message translates to:
  /// **'Center View'**
  String get resetView;

  /// No description provided for @showSiblings.
  ///
  /// In en, this message translates to:
  /// **'Tap to show'**
  String get showSiblings;

  /// No description provided for @addingAdditionalSpouse.
  ///
  /// In en, this message translates to:
  /// **'Adding another spouse. Existing spouse(s) stay linked — this does not replace them.'**
  String get addingAdditionalSpouse;

  /// No description provided for @currentSpousesLabel.
  ///
  /// In en, this message translates to:
  /// **'Currently linked as spouse:'**
  String get currentSpousesLabel;

  /// No description provided for @spouseAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'{name} is already linked as a spouse.'**
  String spouseAlreadyLinked(String name);

  /// No description provided for @removeSpouse.
  ///
  /// In en, this message translates to:
  /// **'Remove Spouse'**
  String get removeSpouse;

  /// No description provided for @confirmRemoveSpouse.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} as a spouse? Their profile will not be deleted.'**
  String confirmRemoveSpouse(String name);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @spouseRemoved.
  ///
  /// In en, this message translates to:
  /// **'Spouse link removed'**
  String get spouseRemoved;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get errorNoInternet;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorServiceFailure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our end. Please try again in a moment.'**
  String get errorServiceFailure;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorEditNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'This change couldn\'t be saved. You may not have permission to edit this person.'**
  String get errorEditNotPermitted;

  /// No description provided for @errorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Please log in instead — if you signed up with a magic link, you\'ll be asked to set a password the next time you log in.'**
  String get errorEmailAlreadyRegistered;

  /// No description provided for @setPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a Password'**
  String get setPasswordTitle;

  /// No description provided for @setPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'You signed in using a magic link. Please set a password now so you can log in on any device without needing to check your email every time.'**
  String get setPasswordDescription;

  /// No description provided for @setPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Set Password'**
  String get setPasswordButton;

  /// No description provided for @passwordSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password set successfully'**
  String get passwordSetSuccess;

  /// No description provided for @duplicateProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Already Linked'**
  String get duplicateProfileTitle;

  /// No description provided for @duplicateProfileFlaggedForReview.
  ///
  /// In en, this message translates to:
  /// **'This profile appears to already be linked to another account of yours. We\'ve flagged it for review so it can be sorted out — no need to do anything else for now.'**
  String get duplicateProfileFlaggedForReview;

  /// No description provided for @errorEmailConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'Account created! Please check your email and tap the confirmation link, then come back and log in to finish joining your family tree.'**
  String get errorEmailConfirmationRequired;

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email first — check your inbox for the confirmation link we sent when you signed up.'**
  String get errorEmailNotConfirmed;

  /// No description provided for @errorPasswordSameAsOld.
  ///
  /// In en, this message translates to:
  /// **'Please choose a different password than the one you already have.'**
  String get errorPasswordSameAsOld;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
