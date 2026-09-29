/// Email/password rules — must match backend/test/validators.test.js.
func checkValidation() {
  func ok(_ e: String) -> Bool { Validation.newEmail(e) == nil }
  assert(ok("  Jane.Doe+bills@Example.COM ")); assert(ok("j.o-e_1@mail.co.uk"))
  for bad in ["jane","jane@","@x.com","jane@x","jane@x.c","jane..doe@x.com",".jane@x.com","jane.@x.com","jane@-x.com","jane doe@x.com","jane@gmial.com", String(repeating:"a",count:65)+"@x.com"] { assert(!ok(bad), bad) }
  assert(Validation.newPassword("short1") != nil); assert(Validation.newPassword("longenoughbutnodigits") != nil)
  assert(Validation.newPassword("Password123") != nil); assert(Validation.newPassword(" BillFixer2026") != nil); assert(Validation.newPassword("aaaa1234xyz") != nil)
  assert(Validation.newPassword("johnsmith99", email: "johnsmith@x.com") != nil); assert(Validation.newPassword("BillFixer2026", email: "johnsmith@x.com") == nil)
  assert(Validation.confirm("a", "b") != nil && Validation.confirm("a", "a") == nil)
 
}
