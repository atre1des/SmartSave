int estimateSimpleInterest({required int principalTenge, required int nominalRateBps, required int months}) {
  if (principalTenge < 0 || nominalRateBps < 0 || months < 0) {
    throw ArgumentError('Principal, rate and term cannot be negative.');
  }
  return (principalTenge * nominalRateBps * months) ~/ 120000;
}

int monthlyGoalContribution({required int targetTenge, required int savedTenge, required int monthsRemaining}) {
  if (targetTenge <= 0 || savedTenge < 0 || monthsRemaining <= 0) {
    throw ArgumentError('Provide a positive target and term, and a non-negative saved amount.');
  }
  final remaining = (targetTenge - savedTenge).clamp(0, targetTenge);
  return (remaining + monthsRemaining - 1) ~/ monthsRemaining;
}
