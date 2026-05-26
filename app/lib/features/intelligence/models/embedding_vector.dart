class EmbeddingVector {
  final List<double> values;
  final bool normalized;

  const EmbeddingVector(this.values, {this.normalized = true});

  int get dimension => values.length;
  bool get isEmpty => values.isEmpty;
}
