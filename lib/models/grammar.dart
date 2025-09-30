class Grammar {
  final String id;
  final String name;
  final int sortOrder;
  final List<GrammarPart> parts;

  Grammar({
    required this.id,
    required this.name,
    required this.parts,
    required this.sortOrder,
  });

  factory Grammar.fromJson(Map<String, dynamic> json) {
    final List<GrammarPart> partsList = [];
    
    if (json['Parts'] != null) {
      final partsData = json['Parts'];
      
      if (partsData is List) {
        // Sắp xếp theo SortOrder nếu có
        final sortedParts = List<Map<String, dynamic>>.from(partsData);
        sortedParts.sort((a, b) {
          final sortOrderA = a['SortOrder'] ?? 999;
          final sortOrderB = b['SortOrder'] ?? 999;
          return sortOrderA.compareTo(sortOrderB);
        });
        
        for (var part in sortedParts) {
          if (part is Map<String, dynamic>) {
            partsList.add(GrammarPart.fromJson(part));
          }
        }
      }
    }

    return Grammar(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      sortOrder: json['SortOrder'] ?? 0,
      parts: partsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'SortOrder': sortOrder,
      'Parts': parts.map((part) => part.toJson()).toList(),
    };
  }
}

class GrammarPart {
  final String id;
  final String name;
  final String theory;
  final String description;
  final int sortOrder;

  GrammarPart({
    required this.id,
    required this.name,
    required this.theory,
    required this.description,
    required this.sortOrder,
  });

  factory GrammarPart.fromJson(Map<String, dynamic> json) {
    return GrammarPart(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      theory: json['Theory'] ?? '',
      description: json['Description'] ?? '',
      sortOrder: json['SortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Theory': theory,
      'Description': description,
      'SortOrder': sortOrder,
    };
  }
}
