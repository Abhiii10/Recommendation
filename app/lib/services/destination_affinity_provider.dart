import '../models/destination.dart';

abstract interface class DestinationAffinityProvider {
  double affinityBoostFor(Destination destination);
}
