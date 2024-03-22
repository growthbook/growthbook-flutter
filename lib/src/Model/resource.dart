class Resource<T> {
  const Resource._();

  factory Resource.success(T data) = Success<T>;

  factory Resource.error(Exception exception) = Error<T>;

  T? get data => null;
}

class Success<T> extends Resource<T> {
  @override
  final T data;

  Success(this.data) : super._();
}

class Error<T> extends Resource<T> {
  final Exception exception;

  Error(this.exception) : super._();
}
