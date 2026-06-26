import 'dart:convert';
import '../core/json_parse.dart';

/// Photo entry from the backend
class UserPhoto {
  final String id;
  final String url;
  final int sortOrder;
  final bool isPrimary;

  const UserPhoto({
    required this.id,
    required this.url,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  factory UserPhoto.fromJson(Map<String, dynamic> json) {
    return UserPhoto(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      sortOrder: asInt(json['sort_order']),
      isPrimary: asBool(json['is_primary']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'sort_order': sortOrder,
        'is_primary': isPrimary,
      };
}

/// Core user shape returned by GET /users and GET /users/:id
class User {
  final dynamic id; // can be int or String depending on backend
  final String name;
  final String? email;
  final String? phone;
  final int? age;
  final String gender; // 'male' | 'female' | 'other'
  final String? city;
  final String? profilePictureUrl;
  final String? primaryPhotoUrl;

  // Extended profile fields
  final String? bio;
  final String? work;
  final String? lookingFor;
  final int? heightCm;
  final int? weightKg;
  final String? drinking;
  final String? smoking;
  final String? religion;
  final String? education;
  final String? educationLevel;
  final List<String> languages;
  final List<String> interests;

  // Photos
  final List<UserPhoto> photoList;

  // Economics / subscription
  final double? walletBalanceUsd;
  final double? lifetimeEarningsUsd;
  final double? todayEarnedUsd;
  final bool? isPremium;
  final String? stripeSubscriptionId;

  // Relation flags (from GET /users)
  final bool isLiked;
  final bool isFavorited;
  final bool isSuperliked;

  // Misc
  final bool? isOnline;
  final bool? isInCall;
  final bool? isSubscribed;
  final double? balance;
  final String? fcmToken;
  final String? createdAt;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.age,
    this.gender = 'other',
    this.city,
    this.profilePictureUrl,
    this.primaryPhotoUrl,
    this.bio,
    this.work,
    this.lookingFor,
    this.heightCm,
    this.weightKg,
    this.drinking,
    this.smoking,
    this.religion,
    this.education,
    this.educationLevel,
    this.languages = const [],
    this.interests = const [],
    this.photoList = const [],
    this.walletBalanceUsd,
    this.lifetimeEarningsUsd,
    this.todayEarnedUsd,
    this.isPremium,
    this.stripeSubscriptionId,
    this.isLiked = false,
    this.isFavorited = false,
    this.isSuperliked = false,
    this.isOnline,
    this.isInCall,
    this.isSubscribed,
    this.balance,
    this.fcmToken,
    this.createdAt,
  });

  bool get isMale => gender == 'male';

  /// Primary display photo URL: first photo > primary_photo_url > profile_picture_url
  String? get displayPhotoUrl {
    // Sort photoList: primary first, then by sort_order
    if (photoList.isNotEmpty) {
      final sorted = [...photoList]..sort((a, b) {
          if (a.isPrimary && !b.isPrimary) return -1;
          if (b.isPrimary && !a.isPrimary) return 1;
          return a.sortOrder.compareTo(b.sortOrder);
        });
      return sorted.first.url;
    }
    return primaryPhotoUrl ?? profilePictureUrl;
  }

  /// Photos sorted: primary first, then by sort_order
  List<UserPhoto> get sortedPhotos {
    if (photoList.isEmpty) return [];
    return [...photoList]..sort((a, b) {
        if (a.isPrimary && !b.isPrimary) return -1;
        if (b.isPrimary && !a.isPrimary) return 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
  }

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse photos list
    List<UserPhoto> photos = [];
    if (json['photos'] is List) {
      photos = (json['photos'] as List)
          .whereType<Map<String, dynamic>>()
          .map(UserPhoto.fromJson)
          .toList();
    }

    // Parse string lists
    List<String> parseStringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: (json['name'] ?? '').toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      age: json['age'] is int
          ? json['age']
          : int.tryParse(json['age']?.toString() ?? ''),
      gender: (json['gender'] ?? 'other').toString(),
      city: json['city']?.toString(),
      profilePictureUrl: json['profile_picture_url']?.toString(),
      primaryPhotoUrl: json['primary_photo_url']?.toString(),
      bio: json['bio']?.toString(),
      work: json['work']?.toString(),
      lookingFor: json['looking_for']?.toString(),
      heightCm: asIntN(json['height_cm']),
      weightKg: asIntN(json['weight_kg']),
      drinking: json['drinking']?.toString(),
      smoking: json['smoking']?.toString(),
      religion: json['religion']?.toString(),
      education: json['education']?.toString(),
      educationLevel: json['education_level']?.toString(),
      languages: parseStringList(json['languages']),
      interests: parseStringList(json['interests']),
      photoList: photos,
      walletBalanceUsd: asDoubleN(json['wallet_balance_usd']),
      lifetimeEarningsUsd: asDoubleN(json['lifetime_earnings_usd']),
      todayEarnedUsd: asDoubleN(json['today_earned_usd']),
      isPremium: json['is_premium'] == null ? null : asBool(json['is_premium']),
      stripeSubscriptionId: json['stripe_subscription_id']?.toString(),
      isLiked: asBool(json['is_liked']),
      isFavorited: asBool(json['is_favorited']),
      isSuperliked: asBool(json['is_superliked']),
      isOnline: json['is_online'] == null ? null : asBool(json['is_online']),
      isInCall: json['is_in_call'] == null ? null : asBool(json['is_in_call']),
      isSubscribed: json['is_subscribed'] == null ? null : asBool(json['is_subscribed']),
      balance: asDoubleN(json['balance']),
      fcmToken: json['fcm_token']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (age != null) 'age': age,
      'gender': gender,
      if (city != null) 'city': city,
      if (profilePictureUrl != null) 'profile_picture_url': profilePictureUrl,
      if (primaryPhotoUrl != null) 'primary_photo_url': primaryPhotoUrl,
      if (bio != null) 'bio': bio,
      if (work != null) 'work': work,
      if (lookingFor != null) 'looking_for': lookingFor,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (drinking != null) 'drinking': drinking,
      if (smoking != null) 'smoking': smoking,
      if (religion != null) 'religion': religion,
      if (education != null) 'education': education,
      if (educationLevel != null) 'education_level': educationLevel,
      'languages': languages,
      'interests': interests,
      'photos': photoList.map((p) => p.toJson()).toList(),
      if (walletBalanceUsd != null) 'wallet_balance_usd': walletBalanceUsd,
      if (lifetimeEarningsUsd != null)
        'lifetime_earnings_usd': lifetimeEarningsUsd,
      if (todayEarnedUsd != null) 'today_earned_usd': todayEarnedUsd,
      if (isPremium != null) 'is_premium': isPremium,
      if (stripeSubscriptionId != null)
        'stripe_subscription_id': stripeSubscriptionId,
      'is_liked': isLiked,
      'is_favorited': isFavorited,
      'is_superliked': isSuperliked,
      if (isOnline != null) 'is_online': isOnline,
      if (isInCall != null) 'is_in_call': isInCall,
      if (isSubscribed != null) 'is_subscribed': isSubscribed,
      if (balance != null) 'balance': balance,
      if (fcmToken != null) 'fcm_token': fcmToken,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  User copyWith({
    dynamic id,
    String? name,
    String? email,
    String? phone,
    int? age,
    String? gender,
    String? city,
    String? profilePictureUrl,
    String? primaryPhotoUrl,
    String? bio,
    String? work,
    String? lookingFor,
    int? heightCm,
    int? weightKg,
    String? drinking,
    String? smoking,
    String? religion,
    String? education,
    String? educationLevel,
    List<String>? languages,
    List<String>? interests,
    List<UserPhoto>? photoList,
    double? walletBalanceUsd,
    double? lifetimeEarningsUsd,
    double? todayEarnedUsd,
    bool? isPremium,
    String? stripeSubscriptionId,
    bool? isLiked,
    bool? isFavorited,
    bool? isSuperliked,
    bool? isOnline,
    bool? isInCall,
    bool? isSubscribed,
    double? balance,
    String? fcmToken,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      primaryPhotoUrl: primaryPhotoUrl ?? this.primaryPhotoUrl,
      bio: bio ?? this.bio,
      work: work ?? this.work,
      lookingFor: lookingFor ?? this.lookingFor,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      drinking: drinking ?? this.drinking,
      smoking: smoking ?? this.smoking,
      religion: religion ?? this.religion,
      education: education ?? this.education,
      educationLevel: educationLevel ?? this.educationLevel,
      languages: languages ?? this.languages,
      interests: interests ?? this.interests,
      photoList: photoList ?? this.photoList,
      walletBalanceUsd: walletBalanceUsd ?? this.walletBalanceUsd,
      lifetimeEarningsUsd: lifetimeEarningsUsd ?? this.lifetimeEarningsUsd,
      todayEarnedUsd: todayEarnedUsd ?? this.todayEarnedUsd,
      isPremium: isPremium ?? this.isPremium,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      isSuperliked: isSuperliked ?? this.isSuperliked,
      isOnline: isOnline ?? this.isOnline,
      isInCall: isInCall ?? this.isInCall,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      balance: balance ?? this.balance,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Full "Me" model — superset of User, returned by GET /users/me
class Me extends User {
  final double? availableCallMinutes;
  final double? minWithdrawalCap;
  final String? stripePriceId;
  final String? stripeSubscriptionStatus;
  final bool? stripeCancelAtPeriodEnd;
  final String? wiseRecipientId;
  final Map<String, dynamic>? wiseRecipientDetails;

  const Me({
    required super.id,
    required super.name,
    super.email,
    super.phone,
    super.age,
    super.gender,
    super.city,
    super.profilePictureUrl,
    super.primaryPhotoUrl,
    super.bio,
    super.work,
    super.lookingFor,
    super.heightCm,
    super.weightKg,
    super.drinking,
    super.smoking,
    super.religion,
    super.education,
    super.educationLevel,
    super.languages,
    super.interests,
    super.photoList,
    super.walletBalanceUsd,
    super.lifetimeEarningsUsd,
    super.todayEarnedUsd,
    super.isPremium,
    super.stripeSubscriptionId,
    super.isLiked,
    super.isFavorited,
    super.isSuperliked,
    super.isOnline,
    super.isInCall,
    super.isSubscribed,
    super.balance,
    super.fcmToken,
    super.createdAt,
    this.availableCallMinutes,
    this.minWithdrawalCap,
    this.stripePriceId,
    this.stripeSubscriptionStatus,
    this.stripeCancelAtPeriodEnd,
    this.wiseRecipientId,
    this.wiseRecipientDetails,
  });

  factory Me.fromJson(Map<String, dynamic> json) {
    final user = User.fromJson(json);
    return Me(
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      age: user.age,
      gender: user.gender,
      city: user.city,
      profilePictureUrl: user.profilePictureUrl,
      primaryPhotoUrl: user.primaryPhotoUrl,
      bio: user.bio,
      work: user.work,
      lookingFor: user.lookingFor,
      heightCm: user.heightCm,
      weightKg: user.weightKg,
      drinking: user.drinking,
      smoking: user.smoking,
      religion: user.religion,
      education: user.education,
      educationLevel: user.educationLevel,
      languages: user.languages,
      interests: user.interests,
      photoList: user.photoList,
      walletBalanceUsd: user.walletBalanceUsd,
      lifetimeEarningsUsd: user.lifetimeEarningsUsd,
      todayEarnedUsd: user.todayEarnedUsd,
      isPremium: user.isPremium,
      stripeSubscriptionId: user.stripeSubscriptionId,
      isLiked: user.isLiked,
      isFavorited: user.isFavorited,
      isSuperliked: user.isSuperliked,
      isOnline: user.isOnline,
      isInCall: user.isInCall,
      isSubscribed: user.isSubscribed,
      balance: user.balance,
      fcmToken: user.fcmToken,
      createdAt: user.createdAt,
      availableCallMinutes: asDoubleN(json['available_call_minutes']),
      minWithdrawalCap: asDoubleN(json['min_withdrawal_cap']),
      stripePriceId: json['stripe_price_id']?.toString(),
      stripeSubscriptionStatus:
          json['stripe_subscription_status']?.toString(),
      stripeCancelAtPeriodEnd: json['stripe_cancel_at_period_end'] == null
          ? null
          : asBool(json['stripe_cancel_at_period_end']),
      wiseRecipientId: json['wise_recipient_id']?.toString(),
      wiseRecipientDetails: json['wise_recipient_details'] is Map
          ? Map<String, dynamic>.from(
              json['wise_recipient_details'] as Map)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    if (availableCallMinutes != null) {
      map['available_call_minutes'] = availableCallMinutes;
    }
    if (minWithdrawalCap != null) map['min_withdrawal_cap'] = minWithdrawalCap;
    if (stripePriceId != null) map['stripe_price_id'] = stripePriceId;
    if (stripeSubscriptionStatus != null) {
      map['stripe_subscription_status'] = stripeSubscriptionStatus;
    }
    if (stripeCancelAtPeriodEnd != null) {
      map['stripe_cancel_at_period_end'] = stripeCancelAtPeriodEnd;
    }
    if (wiseRecipientId != null) map['wise_recipient_id'] = wiseRecipientId;
    if (wiseRecipientDetails != null) {
      map['wise_recipient_details'] = wiseRecipientDetails;
    }
    return map;
  }
}
