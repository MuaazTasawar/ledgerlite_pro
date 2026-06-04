// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_dao.dart';

// ignore_for_file: type=lint
mixin _$LedgerDaoMixin on DatabaseAccessor<AppDatabase> {
  $LedgerEntriesTable get ledgerEntries => attachedDatabase.ledgerEntries;
  $AppMetaTable get appMeta => attachedDatabase.appMeta;
  LedgerDaoManager get managers => LedgerDaoManager(this);
}

class LedgerDaoManager {
  final _$LedgerDaoMixin _db;
  LedgerDaoManager(this._db);
  $$LedgerEntriesTableTableManager get ledgerEntries =>
      $$LedgerEntriesTableTableManager(_db.attachedDatabase, _db.ledgerEntries);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db.attachedDatabase, _db.appMeta);
}
