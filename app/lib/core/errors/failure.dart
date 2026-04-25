sealed class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

final class DataFailure extends Failure {
  const DataFailure(super.message);
}

final class RecommendationFailure extends Failure {
  const RecommendationFailure(super.message);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}

sealed class Result<T> {
  const Result();

  R fold<R>({
    required R Function(T value) onOk,
    required R Function(Failure failure) onErr,
  }) {
    final self = this;
    if (self is Ok<T>) {
      return onOk(self.value);
    }
    if (self is Err<T>) {
      return onErr(self.failure);
    }
    throw StateError('Unknown Result state');
  }

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);
}