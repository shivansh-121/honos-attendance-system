class AppUser {
  final String id, name, username, role, siteId;
  final String? password;
  final double salary;
  
  // Extra HR fields (mirroring Guard model for Supervisors)
  final String empId, phone, dob, address, aadharNo, aadharPhoto, uanNo;
  final String bankName, accountNo, ifsc, branch, passbookPhoto, photo;
  final String joinDate, status;
  final bool isEditableBySupervisor;

  const AppUser({
    required this.id, required this.name, required this.username,
    required this.role, this.siteId = '', this.password,
    this.salary = 0.0,
    this.empId = '', this.phone = '', this.dob = '', this.address = '',
    this.aadharNo = '', this.aadharPhoto = '', this.uanNo = '',
    this.bankName = '', this.accountNo = '', this.ifsc = '',
    this.branch = '', this.passbookPhoto = '', this.photo = '',
    this.joinDate = '', this.status = 'active',
    this.isEditableBySupervisor = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'username': username, 'role': role, 'siteId': siteId, 'password': password,
    'salary': salary,
    'empId': empId, 'phone': phone, 'dob': dob, 'address': address,
    'aadharNo': aadharNo, 'aadharPhoto': aadharPhoto, 'uanNo': uanNo,
    'bankName': bankName, 'accountNo': accountNo, 'ifsc': ifsc,
    'branch': branch, 'passbookPhoto': passbookPhoto, 'photo': photo,
    'joinDate': joinDate, 'status': status,
    'isEditableBySupervisor': isEditableBySupervisor,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] ?? '', name: j['name'] ?? '', username: j['username'] ?? '',
    role: j['role'] ?? '', siteId: j['siteId'] ?? '', password: j['password'],
    salary: (j['salary'] ?? 0).toDouble(),
    empId: j['empId'] ?? '', phone: j['phone'] ?? '', dob: j['dob'] ?? '', address: j['address'] ?? '',
    aadharNo: j['aadharNo'] ?? '', aadharPhoto: j['aadharPhoto'] ?? '', uanNo: j['uanNo'] ?? '',
    bankName: j['bankName'] ?? '', accountNo: j['accountNo'] ?? '', ifsc: j['ifsc'] ?? '',
    branch: j['branch'] ?? '', passbookPhoto: j['passbookPhoto'] ?? '', photo: j['photo'] ?? '',
    joinDate: j['joinDate'] ?? '', status: j['status'] ?? 'active',
    isEditableBySupervisor: j['isEditableBySupervisor'] ?? false,
  );

  AppUser copyWith({
    String? id, String? name, String? username, String? role, String? siteId, String? password,
    double? salary, String? empId, String? phone, String? dob, String? address,
    String? aadharNo, String? aadharPhoto, String? uanNo, String? bankName,
    String? accountNo, String? ifsc, String? branch, String? passbookPhoto,
    String? photo, String? joinDate, String? status, bool? isEditableBySupervisor,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      role: role ?? this.role,
      siteId: siteId ?? this.siteId,
      password: password ?? this.password,
      salary: salary ?? this.salary,
      empId: empId ?? this.empId,
      phone: phone ?? this.phone,
      dob: dob ?? this.dob,
      address: address ?? this.address,
      aadharNo: aadharNo ?? this.aadharNo,
      aadharPhoto: aadharPhoto ?? this.aadharPhoto,
      uanNo: uanNo ?? this.uanNo,
      bankName: bankName ?? this.bankName,
      accountNo: accountNo ?? this.accountNo,
      ifsc: ifsc ?? this.ifsc,
      branch: branch ?? this.branch,
      passbookPhoto: passbookPhoto ?? this.passbookPhoto,
      photo: photo ?? this.photo,
      joinDate: joinDate ?? this.joinDate,
      status: status ?? this.status,
      isEditableBySupervisor: isEditableBySupervisor ?? this.isEditableBySupervisor,
    );
  }
}
