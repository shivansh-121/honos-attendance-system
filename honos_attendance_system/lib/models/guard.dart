class Guard {
  final String id, name, empId, photo, siteId, supervisorId;
  final String phone, dob, address, aadharNo, aadharPhoto, uanNo;
  final String bankName, accountNo, ifsc, branch, passbookPhoto;
  final double salary;
  final String joinDate, status;
  final bool isEditableBySupervisor;

  const Guard({
    required this.id, required this.name, required this.empId,
    required this.siteId, required this.supervisorId,
    this.photo = '', this.phone = '', this.dob = '', this.address = '',
    this.aadharNo = '', this.aadharPhoto = '', this.uanNo = '', this.bankName = '',
    this.accountNo = '', this.ifsc = '', this.branch = '',
    this.passbookPhoto = '', this.salary = 0, this.joinDate = '',
    this.status = 'active', this.isEditableBySupervisor = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'empId': empId, 'photo': photo,
    'siteId': siteId, 'supervisorId': supervisorId, 'phone': phone,
    'dob': dob, 'address': address, 'aadharNo': aadharNo,
    'aadharPhoto': aadharPhoto, 'uanNo': uanNo, 'bankName': bankName, 'accountNo': accountNo,
    'ifsc': ifsc, 'branch': branch, 'passbookPhoto': passbookPhoto,
    'salary': salary, 'joinDate': joinDate, 'status': status,
    'isEditableBySupervisor': isEditableBySupervisor,
  };

  factory Guard.fromJson(Map<String, dynamic> j) => Guard(
    id: j['id'] ?? '', name: j['name'] ?? '', empId: j['empId'] ?? '',
    photo: j['photo'] ?? '', siteId: j['siteId'] ?? '',
    supervisorId: j['supervisorId'] ?? '', phone: j['phone'] ?? '',
    dob: j['dob'] ?? '', address: j['address'] ?? '',
    aadharNo: j['aadharNo'] ?? '', aadharPhoto: j['aadharPhoto'] ?? '',
    uanNo: j['uanNo'] ?? '', bankName: j['bankName'] ?? '', accountNo: j['accountNo'] ?? '',
    ifsc: j['ifsc'] ?? '', branch: j['branch'] ?? '',
    passbookPhoto: j['passbookPhoto'] ?? '',
    salary: (j['salary'] ?? 0).toDouble(),
    joinDate: j['joinDate'] ?? '', status: j['status'] ?? 'active',
    isEditableBySupervisor: j['isEditableBySupervisor'] ?? false,
  );
}
