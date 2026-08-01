class ConflictResolver {
  const ConflictResolver();

  T resolve<T>({
    required T local,
    required T remote,
    required DateTime Function(T item) updatedAtOf,
  }) {
    return updatedAtOf(remote).isAfter(updatedAtOf(local)) ? remote : local;
  }
}