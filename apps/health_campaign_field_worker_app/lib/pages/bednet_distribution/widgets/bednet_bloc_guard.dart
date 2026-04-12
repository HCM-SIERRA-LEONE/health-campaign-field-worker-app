import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/bednet_distribution/bednet_distribution.dart';

/// Returns [BednetDistributionBloc] when present in the widget tree.
BednetDistributionBloc? maybeBednetDistributionBloc(BuildContext context) {
  try {
    return context.read<BednetDistributionBloc>();
  } catch (_) {
    return null;
  }
}

/// Fallback when [BednetDistributionBloc] is not provided.
Widget missingBednetDistributionBlocFallback(BuildContext context) {
  return const Scaffold(
    body: Center(child: Text('Distribution context unavailable.')),
  );
}
