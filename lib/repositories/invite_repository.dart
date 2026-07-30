import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invite_model.dart';

const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

enum InviteFailureReason { notFound, expired, alreadyUsed }

sealed class InviteRedeemResult {}

class InviteRedeemSuccess extends InviteRedeemResult {
  InviteRedeemSuccess(this.contactId, this.ownerUid);
  final String contactId;
  final String ownerUid;
}

class InviteRedeemFailure extends InviteRedeemResult {
  InviteRedeemFailure(this.reason);
  final InviteFailureReason reason;
}

class InviteRepository {
  InviteRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('invites');

  String _generateCode() {
    final random = Random.secure();
    return List.generate(6, (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)]).join();
  }

  Future<String> createInvite({
    required String ownerUid,
    required String contactId,
    DateTime? now,
  }) async {
    final createdAt = now ?? DateTime.now();
    final code = _generateCode();
    final invite = InviteModel(
      code: code,
      ownerUid: ownerUid,
      contactId: contactId,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 24)),
    );
    await _collection.doc(code).set(invite.toMap());
    return code;
  }

  Future<InviteRedeemResult> redeemInvite({
    required String code,
    required String redeemerUid,
  }) async {
    final doc = await _collection.doc(code).get();
    if (!doc.exists) {
      return InviteRedeemFailure(InviteFailureReason.notFound);
    }

    final invite = InviteModel.fromMap(code, doc.data()!);
    if (invite.used) {
      return InviteRedeemFailure(InviteFailureReason.alreadyUsed);
    }
    if (DateTime.now().isAfter(invite.expiresAt)) {
      return InviteRedeemFailure(InviteFailureReason.expired);
    }

    await _firestore
        .collection('users')
        .doc(invite.ownerUid)
        .collection('contacts')
        .doc(invite.contactId)
        .update({'linkedUid': redeemerUid});
    await _collection.doc(code).update({'used': true});

    return InviteRedeemSuccess(invite.contactId, invite.ownerUid);
  }
}
