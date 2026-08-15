import 'package:hive/hive.dart';

part 'family_member.g.dart';

@HiveType(typeId: 0)
class FamilyMember extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime createdAt;

  @HiveField(2)
  String? authUserId;

  @HiveField(3)
  String? fatherId;

  @HiveField(4)
  String? motherId;

  // NOTE: HiveField(5) used to be `spouseId` (single spouse). Spouse is now a
  // many-to-many relation stored separately in spouse_relationships / a local
  // spouse-links cache, not a field on this model. Field index 5 is retired
  // and must never be reused for a new field (stale cached data on old
  // installs still has that index written).

  @HiveField(6)
  String firstNameEn;

  @HiveField(7)
  String? firstNameGu;

  @HiveField(8)
  String lastNameEn;

  @HiveField(9)
  String? lastNameGu;

  @HiveField(10)
  String? gender;

  @HiveField(11)
  DateTime? dob;

  @HiveField(12)
  bool isAlive;

  @HiveField(13)
  String? villageOrigin;

  @HiveField(14)
  String? currentCity;

  @HiveField(15)
  Map<String, dynamic> deepDetails;

  @HiveField(16)
  bool isPendingSync;

  @HiveField(17)
  DateTime? lastModified;

  @HiveField(18)
  String? inviteCode;

  FamilyMember({
    required this.id,
    required this.createdAt,
    this.authUserId,
    this.fatherId,
    this.motherId,
    required this.firstNameEn,
    this.firstNameGu,
    required this.lastNameEn,
    this.lastNameGu,
    this.gender,
    this.dob,
    this.isAlive = true,
    this.villageOrigin,
    this.currentCity,
    this.deepDetails = const {},
    this.isPendingSync = false,
    this.lastModified,
    this.inviteCode,
  });

  String get fullNameEn => '$firstNameEn $lastNameEn';
  String get fullNameGu => '${firstNameGu ?? firstNameEn} ${lastNameGu ?? lastNameEn}';
  
  String getFullName(String locale) {
    if (locale == 'gu' && firstNameGu != null) {
      return fullNameGu;
    }
    return fullNameEn;
  }

  /// A single uppercase character for avatar initials. `first_name_en` is
  /// only `NOT NULL` at the schema level, not non-empty — a row inserted
  /// directly via the Supabase SQL editor (or any path bypassing the app's
  /// own required-field validation) could have `''`, which would throw a
  /// RangeError on a bare `.substring(0, 1)`. Falls back to '?' rather than
  /// crashing every avatar that renders this member.
  String get initial =>
      firstNameEn.isNotEmpty ? firstNameEn[0].toUpperCase() : '?';

  bool get isClaimed => authUserId != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'auth_user_id': authUserId,
      'father_id': fatherId,
      'mother_id': motherId,
      'first_name_en': firstNameEn,
      'first_name_gu': firstNameGu,
      'last_name_en': lastNameEn,
      'last_name_gu': lastNameGu,
      'gender': gender,
      'dob': dob?.toIso8601String(),
      'is_alive': isAlive,
      'village_origin': villageOrigin,
      'current_city': currentCity,
      'deep_details': deepDetails,
      'invite_code': inviteCode,
    };
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authUserId: json['auth_user_id'] as String?,
      fatherId: json['father_id'] as String?,
      motherId: json['mother_id'] as String?,
      firstNameEn: json['first_name_en'] as String,
      firstNameGu: json['first_name_gu'] as String?,
      lastNameEn: json['last_name_en'] as String,
      lastNameGu: json['last_name_gu'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
      isAlive: json['is_alive'] as bool? ?? true,
      villageOrigin: json['village_origin'] as String?,
      currentCity: json['current_city'] as String?,
      deepDetails: (json['deep_details'] as Map<String, dynamic>?) ?? {},
      isPendingSync: false,
      lastModified: DateTime.now(),
      inviteCode: json['invite_code'] as String?,
    );
  }

  FamilyMember copyWith({
    String? id,
    DateTime? createdAt,
    String? authUserId,
    String? fatherId,
    String? motherId,
    String? firstNameEn,
    String? firstNameGu,
    String? lastNameEn,
    String? lastNameGu,
    String? gender,
    DateTime? dob,
    bool? isAlive,
    String? villageOrigin,
    String? currentCity,
    Map<String, dynamic>? deepDetails,
    bool? isPendingSync,
    DateTime? lastModified,
    String? inviteCode,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      authUserId: authUserId ?? this.authUserId,
      fatherId: fatherId ?? this.fatherId,
      motherId: motherId ?? this.motherId,
      firstNameEn: firstNameEn ?? this.firstNameEn,
      firstNameGu: firstNameGu ?? this.firstNameGu,
      lastNameEn: lastNameEn ?? this.lastNameEn,
      lastNameGu: lastNameGu ?? this.lastNameGu,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      isAlive: isAlive ?? this.isAlive,
      villageOrigin: villageOrigin ?? this.villageOrigin,
      currentCity: currentCity ?? this.currentCity,
      deepDetails: deepDetails ?? this.deepDetails,
      isPendingSync: isPendingSync ?? this.isPendingSync,
      lastModified: lastModified ?? this.lastModified,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}

enum RelationType {
  father,
  mother,
  spouse,
  child,
  sibling,
}

/// A spousal link between two members (supports remarriage — a member can
/// appear in more than one SpouseLink). Mirrors a row in
/// `public.spouse_relationships`; direction (member/spouse) is arbitrary,
/// not semantic — check both fields when looking up "the other side."
class SpouseLink {
  final String memberId;
  final String spouseId;

  const SpouseLink({required this.memberId, required this.spouseId});

  /// Given one side of the link, returns the other member's id.
  String otherId(String knownId) => knownId == memberId ? spouseId : memberId;

  factory SpouseLink.fromJson(Map<String, dynamic> json) {
    return SpouseLink(
      memberId: json['member_id'] as String,
      spouseId: json['spouse_id'] as String,
    );
  }
}
