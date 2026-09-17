import 'package:equatable/equatable.dart';

/// Mirrors `AgencyFinancial.model.js`'s `TRANSACTION_TYPES` /
/// `agency.validator.js`'s `ledgerEntrySchema#transaction_type`.
enum LedgerTransactionType { registrationFee, commission }

extension LedgerTransactionTypeWire on LedgerTransactionType {
  /// The exact string the backend sends/expects — not a Dart-style name.
  String get wireValue {
    switch (this) {
      case LedgerTransactionType.registrationFee:
        return 'registration_fee';
      case LedgerTransactionType.commission:
        return 'commission';
    }
  }

  String get label {
    switch (this) {
      case LedgerTransactionType.registrationFee:
        return 'Registration fee';
      case LedgerTransactionType.commission:
        return 'Commission';
    }
  }
}

LedgerTransactionType ledgerTransactionTypeFromWire(String value) =>
    LedgerTransactionType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => LedgerTransactionType.commission,
    );

/// One row on the agency's financial ledger. Mirrors
/// `AgencyFinancial.model.js`'s `toJSON()` output.
class AgencyLedgerEntry extends Equatable {
  const AgencyLedgerEntry({
    required this.id,
    required this.agencyId,
    required this.amount,
    required this.transactionType,
    required this.date,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String agencyId;
  final double amount;
  final LedgerTransactionType transactionType;
  final String? description;

  /// The accounting date this entry is booked against — distinct from
  /// [createdAt] (see `AgencyFinancial.model.js`'s doc comment on
  /// `date` vs `createdAt`).
  final DateTime date;
  final DateTime createdAt;

  factory AgencyLedgerEntry.fromJson(Map<String, dynamic> json) =>
      AgencyLedgerEntry(
        id: json['id'] as String,
        agencyId: json['agencyId'] as String,
        amount: (json['amount'] as num).toDouble(),
        transactionType:
            ledgerTransactionTypeFromWire(json['transactionType'] as String),
        description: json['description'] as String?,
        date: DateTime.parse(json['date'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props =>
      [id, agencyId, amount, transactionType, description, date, createdAt];
}

/// POST /agencies/finance/ledger request body. `date` is left
/// unset (omitted from the wire payload) for the common "log it for
/// today" case — the backend defaults it to `now` (see
/// `agency.service.js#recordLedgerEntry`) — and only sent when the
/// desk worker is explicitly backfilling an earlier entry.
class LedgerEntryPayload {
  const LedgerEntryPayload({
    required this.amount,
    required this.transactionType,
    this.description,
    this.date,
  });

  final double amount;
  final LedgerTransactionType transactionType;
  final String? description;
  final DateTime? date;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'transaction_type': transactionType.wireValue,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (date != null) 'date': date!.toIso8601String(),
      };
}

/// POST /agencies/finance/ledger response — the entry just recorded,
/// plus the agency's running balance after it was applied.
class LedgerEntryResult extends Equatable {
  const LedgerEntryResult({required this.entry, required this.ledgerBalance});

  final AgencyLedgerEntry entry;
  final double ledgerBalance;

  factory LedgerEntryResult.fromJson(Map<String, dynamic> json) =>
      LedgerEntryResult(
        entry: AgencyLedgerEntry.fromJson(json['entry'] as Map<String, dynamic>),
        ledgerBalance: (json['ledgerBalance'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [entry, ledgerBalance];
}

/// `revenue` block of GET /agencies/dashboard/stats.
class AgencyDashboardRevenue extends Equatable {
  const AgencyDashboardRevenue({
    required this.registrationFeesToday,
    required this.commissionsToday,
    required this.netRevenueToday,
  });

  final double registrationFeesToday;
  final double commissionsToday;
  final double netRevenueToday;

  factory AgencyDashboardRevenue.fromJson(Map<String, dynamic> json) =>
      AgencyDashboardRevenue(
        registrationFeesToday: (json['registrationFeesToday'] as num).toDouble(),
        commissionsToday: (json['commissionsToday'] as num).toDouble(),
        netRevenueToday: (json['netRevenueToday'] as num).toDouble(),
      );

  @override
  List<Object?> get props =>
      [registrationFeesToday, commissionsToday, netRevenueToday];
}

/// GET /agencies/dashboard/stats response — today's (or an explicitly
/// requested day's) operational KPIs plus the running ledger balance.
/// Mirrors `agency.service.js#getDashboardStats`'s return shape.
class AgencyDashboardStats extends Equatable {
  const AgencyDashboardStats({
    required this.date,
    required this.walkInsRegisteredToday,
    required this.dispatchesSentToday,
    required this.successfulPlacementsToday,
    required this.revenue,
    required this.ledgerBalance,
  });

  /// `yyyy-MM-dd`, the UTC calendar day these stats cover.
  final String date;
  final int walkInsRegisteredToday;
  final int dispatchesSentToday;
  final int successfulPlacementsToday;
  final AgencyDashboardRevenue revenue;
  final double ledgerBalance;

  factory AgencyDashboardStats.fromJson(Map<String, dynamic> json) =>
      AgencyDashboardStats(
        date: json['date'] as String,
        walkInsRegisteredToday: json['walkInsRegisteredToday'] as int,
        dispatchesSentToday: json['dispatchesSentToday'] as int,
        successfulPlacementsToday: json['successfulPlacementsToday'] as int,
        revenue:
            AgencyDashboardRevenue.fromJson(json['revenue'] as Map<String, dynamic>),
        ledgerBalance: (json['ledgerBalance'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [
        date,
        walkInsRegisteredToday,
        dispatchesSentToday,
        successfulPlacementsToday,
        revenue,
        ledgerBalance,
      ];
}
