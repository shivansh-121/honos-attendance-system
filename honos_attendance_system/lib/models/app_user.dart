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
    id: j['id']?.toString() ?? '', name: j['name']?.toString() ?? '', username: j['username']?.toString() ?? '',
    role: j['role']?.toString() ?? '', siteId: j['siteId']?.toString() ?? '', password: j['password']?.toString(),
    salary: double.tryParse(j['salary']?.toString() ?? '0') ?? 0.0,
    empId: j['empId']?.toString() ?? '', phone: j['phone']?.toString() ?? '', dob: j['dob']?.toString() ?? '', address: j['address']?.toString() ?? '',
    aadharNo: j['aadharNo']?.toString() ?? '', aadharPhoto: j['aadharPhoto']?.toString() ?? '', uanNo: j['uanNo']?.toString() ?? '',
    bankName: j['bankName']?.toString() ?? '', accountNo: j['accountNo']?.toString() ?? '', ifsc: j['ifsc']?.toString() ?? '',
    branch: j['branch']?.toString() ?? '', passbookPhoto: j['passbookPhoto']?.toString() ?? '', photo: j['photo']?.toString() ?? '',
    joinDate: j['joinDate']?.toString() ?? '', status: j['status']?.toString() ?? 'active',
    isEditableBySupervisor: j['isEditableBySupervisor'] == true || j['isEditableBySupervisor'] == 'true',
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
