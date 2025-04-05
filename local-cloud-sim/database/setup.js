rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "192.168.58.10:27017" },
    { _id: 1, host: "192.168.58.11:27017" },
  ]
});
/*use admin:
db.createUser({
  user: "admin",
  pwd: "supersecurepassword",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]
})*/
