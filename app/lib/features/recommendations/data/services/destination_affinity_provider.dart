import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';

abstract interface class DestinationAffinityProvider {
  double affinityBoostFor(Destination destination);
}
