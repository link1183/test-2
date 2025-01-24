class Status {
  final int id;
  final String name;

  Status({required this.id, required this.name});
}

class Category {
  final int id;
  final String name;

  Category({required this.id, required this.name});
}

class Keyword {
  final int id;
  final String keyword;

  Keyword({required this.id, required this.keyword});
}

class KeywordsLinks {
  final int linkId;
  final int keywordId;
  final Link link;
  final Keyword keyword;

  KeywordsLinks({
    required this.linkId,
    required this.keywordId,
    required this.link,
    required this.keyword,
  });
}

class Link {
  final int id;
  final String title;
  final String description;
  final String? docLink;
  final int statusId;
  final int categoryId;
  final Status status;
  final Category category;

  Link({
    required this.id,
    required this.title,
    required this.description,
    required this.docLink,
    required this.statusId,
    required this.categoryId,
    required this.status,
    required this.category,
  });
}

class LinkManagersLinks {
  final int linkId;
  final int managerId;
  final Link link;
  final LinkManager manager;

  LinkManagersLinks({
    required this.linkId,
    required this.managerId,
    required this.link,
    required this.manager,
  });
}

class LinkManager {
  final int id;
  final String name;
  final String surname;

  LinkManager({
    required this.id,
    required this.name,
    required this.surname,
  });
}

class LinksViews {
  final int linkId;
  final int viewId;
  final Link link;
  final View view;

  LinksViews({
    required this.linkId,
    required this.viewId,
    required this.link,
    required this.view,
  });
}

class View {
  final int id;
  final String name;

  View({required this.id, required this.name});
}
