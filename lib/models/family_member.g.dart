// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_member.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FamilyMemberAdapter extends TypeAdapter<FamilyMember> {
  @override
  final int typeId = 0;

  @override
  FamilyMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FamilyMember(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      authUserId: fields[2] as String?,
      fatherId: fields[3] as String?,
      motherId: fields[4] as String?,
      firstNameEn: fields[6] as String,
      firstNameGu: fields[7] as String?,
      lastNameEn: fields[8] as String,
      lastNameGu: fields[9] as String?,
      gender: fields[10] as String?,
      dob: fields[11] as DateTime?,
      isAlive: fields[12] as bool,
      villageOrigin: fields[13] as String?,
      currentCity: fields[14] as String?,
      deepDetails: (fields[15] as Map).cast<String, dynamic>(),
      isPendingSync: fields[16] as bool,
      lastModified: fields[17] as DateTime?,
      inviteCode: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FamilyMember obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.authUserId)
      ..writeByte(3)
      ..write(obj.fatherId)
      ..writeByte(4)
      ..write(obj.motherId)
      ..writeByte(6)
      ..write(obj.firstNameEn)
      ..writeByte(7)
      ..write(obj.firstNameGu)
      ..writeByte(8)
      ..write(obj.lastNameEn)
      ..writeByte(9)
      ..write(obj.lastNameGu)
      ..writeByte(10)
      ..write(obj.gender)
      ..writeByte(11)
      ..write(obj.dob)
      ..writeByte(12)
      ..write(obj.isAlive)
      ..writeByte(13)
      ..write(obj.villageOrigin)
      ..writeByte(14)
      ..write(obj.currentCity)
      ..writeByte(15)
      ..write(obj.deepDetails)
      ..writeByte(16)
      ..write(obj.isPendingSync)
      ..writeByte(17)
      ..write(obj.lastModified)
      ..writeByte(18)
      ..write(obj.inviteCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FamilyMemberAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
