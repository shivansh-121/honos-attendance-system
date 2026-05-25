class AppUser {
  final String id, name, username, role, siteId;
  final String? password;
  final double salary;
  
  // Extra HR fields (mirroring Guard model for Supervisors)
  final String empId, phone, dob, address, aadharNo, aadharPhoto, uanNo;
  final String bankName, accountNo, ifsc, branch, passbookPhoto, photo;
  final String joinDate, status;

  const AppUser({
    required this.id, required this.name, required this.username,
    required this.role, this.siteId = '', this.password,
    this.salary = 0.0,
    this.empId = '', this.phone = '', this.dob = '', this.address = '',
    this.aadharNo = '', this.aadharPhoto = '', this.uanNo = '',
    this.bankName = '', this.accountNo = '', this.ifsc = '',
    this.branch = '', this.passbookPhoto = '', this.photo = '',
    this.joinDate = '', this.status = 'active',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'username': username, 'role': role, 'siteId': siteId, 'password': password,
    'salary': salary,
    'empId': empId, 'phone': phone, 'dob': dob, 'address': address,
    'aadharNo': aadharNo, 'aadharPhoto': aadharPhoto, 'uanNo': uanNo,
    'bankName': bankName, 'accountNo': accountNo, 'ifsc': ifsc,
    'branch': branch, 'passbookPhoto': passbookPhoto, 'photo': photo,
    'joinDate': joinDate, 'status': status,
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
  );
}
