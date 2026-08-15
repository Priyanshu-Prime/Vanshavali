// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vanshavali';

  @override
  String get welcomeMessage => 'Welcome to Vanshavali';

  @override
  String get welcomeSubtitle =>
      'Connect with your roots, discover your lineage';

  @override
  String get login => 'Login';

  @override
  String get signUp => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get sendMagicLink => 'Send Magic Link';

  @override
  String get magicLinkSent => 'Magic link sent! Check your email.';

  @override
  String get orContinueWith => 'Or continue with';

  @override
  String get emailPassword => 'Email & Password';

  @override
  String get createAccount => 'Create Account';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get logout => 'Logout';

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get firstName => 'First Name';

  @override
  String get firstNameGujarati => 'First Name (Gujarati)';

  @override
  String get lastName => 'Last Name';

  @override
  String get lastNameGujarati => 'Last Name (Gujarati)';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get other => 'Other';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get isAlive => 'Living';

  @override
  String get deceased => 'Deceased';

  @override
  String get villageOrigin => 'Village of Origin';

  @override
  String get currentCity => 'Current City';

  @override
  String get education => 'Education';

  @override
  String get occupation => 'Occupation';

  @override
  String get medicalInfo => 'Medical Information';

  @override
  String get familyTree => 'Family Tree';

  @override
  String get myFamily => 'My Family';

  @override
  String get father => 'Father';

  @override
  String get mother => 'Mother';

  @override
  String get spouse => 'Spouse';

  @override
  String get spouses => 'Spouses';

  @override
  String get children => 'Children';

  @override
  String get siblings => 'Siblings';

  @override
  String get addFather => 'Add Father';

  @override
  String get addMother => 'Add Mother';

  @override
  String get addSpouse => 'Add Spouse';

  @override
  String get addChild => 'Add Child';

  @override
  String get addSibling => 'Add Sibling';

  @override
  String get addFamilyMember => 'Add Family Member';

  @override
  String get linkExisting => 'Link Existing Member';

  @override
  String get createNew => 'Create New';

  @override
  String get searchMembers => 'Search Members';

  @override
  String get inviteMember => 'Invite Member';

  @override
  String get inviteSent => 'Invitation sent!';

  @override
  String get claimProfile => 'Claim Profile';

  @override
  String get viewProfile => 'View Profile';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get gujarati => 'ગુજરાતી';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get syncData => 'Sync Data';

  @override
  String lastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String get noInternet => 'No internet connection';

  @override
  String get dataWillSync => 'Your changes will sync when online';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get required => 'Required';

  @override
  String get invalidEmail => 'Invalid email address';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get completeProfile => 'Complete Your Profile';

  @override
  String get profileCompleted => 'Profile completed successfully!';

  @override
  String get translateToGujarati => 'Translate to Gujarati';

  @override
  String get noFamilyMembers => 'No family members added yet';

  @override
  String get tapToAdd => 'Tap + to add family members';

  @override
  String relationshipWith(String name) {
    return 'Relationship with $name';
  }

  @override
  String get confirmDelete => 'Are you sure you want to delete?';

  @override
  String get deleteWarning => 'This action cannot be undone';

  @override
  String get share => 'Share';

  @override
  String get copyInviteLink => 'Copy Invite Link';

  @override
  String get linkCopied => 'Link copied to clipboard';

  @override
  String get aboutApp => 'About Vanshavali';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get notifications => 'Notifications';

  @override
  String get pendingInvites => 'Pending Invites';

  @override
  String get acceptInvite => 'Accept';

  @override
  String get declineInvite => 'Decline';

  @override
  String get selectDate => 'Select Date';

  @override
  String get selectGender => 'Select Gender';

  @override
  String get continueText => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get getStarted => 'Get Started';

  @override
  String get onboardingTitle1 => 'Discover Your Roots';

  @override
  String get onboardingDesc1 =>
      'Explore your family history and connect generations';

  @override
  String get onboardingTitle2 => 'Build Your Tree';

  @override
  String get onboardingDesc2 =>
      'Add family members and create visual connections';

  @override
  String get onboardingTitle3 => 'Stay Connected';

  @override
  String get onboardingDesc3 => 'Invite relatives and grow your family network';

  @override
  String get onboardingTitle4 => 'Your Privacy';

  @override
  String get onboardingDesc4 =>
      'Your family details are visible to other logged-in members of this app and stored securely with Supabase. You can review this anytime in Settings.';

  @override
  String get privacyNotice => 'Privacy Notice';

  @override
  String get privacyNoticeBody =>
      'Vanshavali stores your family tree data (names, relationships, and any details you add) with Supabase, our hosting provider. Once you\'re logged in, other members of this app\'s community can view the shared family tree. Only you can edit your own profile, or an unclaimed relative\'s profile until they claim it themselves.';

  @override
  String get close => 'Close';

  @override
  String get unknown => 'Unknown';

  @override
  String get name => 'Name';

  @override
  String get basicInformation => 'Basic Information';

  @override
  String get location => 'Location';

  @override
  String get additionalDetails => 'Additional Details';

  @override
  String get relationship => 'Relationship';

  @override
  String get addMethod => 'Add Method';

  @override
  String get pleaseSelectRelationship => 'Please select a relationship';

  @override
  String get pleaseSelectGender => 'Please select a gender';

  @override
  String get completeProfileFirst => 'Please complete your profile first';

  @override
  String alreadyExists(String relation) {
    return '$relation already exists. Edit the existing one instead.';
  }

  @override
  String ancestryCycleBlocked(String name) {
    return '$name can\'t be set as this relation — they\'re already a descendant, and this would create a loop in the family tree.';
  }

  @override
  String confirmAddMemberTarget(
    String name,
    String ownerName,
    String relation,
  ) {
    return 'Add \"$name\" as $ownerName\'s $relation?';
  }

  @override
  String confirmAddMemberSelf(String name, String relation) {
    return 'Add \"$name\" as your $relation?';
  }

  @override
  String get confirm => 'Confirm';

  @override
  String get add => 'Add';

  @override
  String get familyMemberAdded => 'Family member added successfully';

  @override
  String get familyMemberAddedPartial =>
      'Family member added, but linking some existing children to them failed — please check and try again';

  @override
  String get noResultsFound => 'No matching members found';

  @override
  String whoIsThe(String relation) {
    return 'Who is the $relation?';
  }

  @override
  String get selectOtherParent => 'Select the other parent of this child.';

  @override
  String get verified => 'Verified';

  @override
  String get unclaimed => 'Unclaimed';

  @override
  String addRelation(String relation) {
    return 'Add $relation';
  }

  @override
  String get someoneElse => 'Someone else';

  @override
  String get createNewProfile => 'Create a new profile';

  @override
  String newRelation(String relation) {
    return 'New $relation';
  }

  @override
  String get firstNameRequired => 'First Name *';

  @override
  String get lastNameRequired => 'Last Name *';

  @override
  String get enterBothNames => 'Please enter both first and last name';

  @override
  String get skipOtherParent => 'Skip — Don\'t set other parent';

  @override
  String get verifiedMember => 'Verified Member';

  @override
  String get unclaimedProfile => 'Unclaimed Profile';

  @override
  String get status => 'Status';

  @override
  String get inviteDescription =>
      'This profile hasn\'t been claimed yet. Share an invite link so they can join and manage their own profile.';

  @override
  String get deleteProfile => 'Delete Profile';

  @override
  String confirmDeleteMember(String name) {
    return 'Are you sure you want to delete $name\'s profile? This action cannot be undone.';
  }

  @override
  String memberDeleted(String name) {
    return '$name has been deleted.';
  }

  @override
  String failedToDelete(String error) {
    return 'Failed to delete profile: $error';
  }

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get familyRelations => 'Family Relations';

  @override
  String get centerOnMe => 'Center on me';

  @override
  String get centerOnMember => 'Center on this member';

  @override
  String get addRelativeForYourself => 'Add a relative for yourself';

  @override
  String addRelativeFor(String name) {
    return 'Add a relative for $name';
  }

  @override
  String get online => 'Online';

  @override
  String get fullSyncComplete => 'Full sync complete';

  @override
  String get fullSync => 'Full Sync';

  @override
  String get confirmLogout => 'Are you sure you want to logout?';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get defaultView => 'Family';

  @override
  String get pedigreeView => 'Pedigree';

  @override
  String get editGujaratiSpelling => 'Edit Gujarati Spelling';

  @override
  String get autoTranslation => 'Auto Translation';

  @override
  String get transliteration => 'Transliteration';

  @override
  String get typeManually => 'Type manually in Gujarati';

  @override
  String get apply => 'Apply';

  @override
  String get noEnglishText => 'Enter the English name first';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get resetPasswordDesc =>
      'Enter your email and we will send you a password reset link.';

  @override
  String get resetLinkSent => 'Password reset link sent! Check your email.';

  @override
  String get send => 'Send';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get featureComingSoon => 'This feature is coming soon.';

  @override
  String get inviteCode => 'Invite Code';

  @override
  String get inviteCodeDesc =>
      'Share this code with the person. They can enter it during sign up to claim this profile.';

  @override
  String get enterInviteCode => 'Have an invite code?';

  @override
  String get enterInviteCodeHint => 'Enter 6-character code';

  @override
  String get claimWithCode => 'Claim Profile';

  @override
  String get invalidInviteCode => 'Invalid or expired invite code';

  @override
  String get profileClaimed => 'Profile claimed successfully!';

  @override
  String get codeCopied => 'Invite code copied';

  @override
  String get generatingCode => 'Generating code...';

  @override
  String get orUseInviteCode => 'Or enter an invite code';

  @override
  String get linkChildrenToSpouse => 'Link children to spouse?';

  @override
  String get linkChildrenToSpouseDesc =>
      'These children don\'t have the other parent set. Would you like to link them to the new spouse?';

  @override
  String get zoomIn => 'Zoom In';

  @override
  String get zoomOut => 'Zoom Out';

  @override
  String get resetView => 'Center View';

  @override
  String get showSiblings => 'Tap to show';

  @override
  String get addingAdditionalSpouse =>
      'Adding another spouse. Existing spouse(s) stay linked — this does not replace them.';

  @override
  String get currentSpousesLabel => 'Currently linked as spouse:';

  @override
  String spouseAlreadyLinked(String name) {
    return '$name is already linked as a spouse.';
  }

  @override
  String get removeSpouse => 'Remove Spouse';

  @override
  String confirmRemoveSpouse(String name) {
    return 'Remove $name as a spouse? Their profile will not be deleted.';
  }

  @override
  String get remove => 'Remove';

  @override
  String get spouseRemoved => 'Spouse link removed';

  @override
  String get errorNoInternet =>
      'No internet connection. Please check your network and try again.';

  @override
  String get errorTimeout => 'That took too long. Please try again.';

  @override
  String get errorServiceFailure =>
      'Something went wrong on our end. Please try again in a moment.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorEmailAlreadyRegistered =>
      'An account with this email already exists. Please log in instead — if you signed up with a magic link, you\'ll be asked to set a password the next time you log in.';

  @override
  String get setPasswordTitle => 'Set a Password';

  @override
  String get setPasswordDescription =>
      'You signed in using a magic link. Please set a password now so you can log in on any device without needing to check your email every time.';

  @override
  String get setPasswordButton => 'Set Password';

  @override
  String get passwordSetSuccess => 'Password set successfully';
}
