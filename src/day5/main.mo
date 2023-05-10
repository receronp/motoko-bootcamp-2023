import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Hash "mo:base/Hash";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Timer "mo:base/Timer";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";

import IC "Ic";
import Type "Types";
import Iter "mo:base/Iter";

actor class Verifier() {
  type StudentProfile = Type.StudentProfile;
  private stable var studentProfileEntries : [(Principal, StudentProfile)] = [];
  private var studentProfileStore = HashMap.HashMap<Principal, StudentProfile>(1, Principal.equal, Principal.hash);

  // STEP 1 - BEGIN
  public shared ({ caller }) func addMyProfile(profile : StudentProfile) : async Result.Result<(), Text> {
    studentProfileStore.put(caller, profile);
    return #ok();
  };

  public shared query func seeAProfile(p : Principal) : async Result.Result<StudentProfile, Text> {
    switch (studentProfileStore.get(p)) {
      case null #err("Student profile not found");
      case (?value) #ok(value);
    };
  };

  public shared ({ caller }) func updateMyProfile(profile : StudentProfile) : async Result.Result<(), Text> {
    switch (studentProfileStore.get(caller)) {
      case null #err("Student profile not found");
      case (?value) {
        studentProfileStore.put(caller, profile);
        return #ok();
      };
    };
  };

  public shared ({ caller }) func deleteMyProfile() : async Result.Result<(), Text> {
    switch (studentProfileStore.get(caller)) {
      case null #err("Student profile not found");
      case (?value) {
        studentProfileStore.delete(caller);
        return #ok();
      };
    };
  };

  system func preupgrade() {
    studentProfileEntries := Iter.toArray(studentProfileStore.entries());
  };

  system func postupgrade() {
    studentProfileStore := HashMap.fromIter<Principal, StudentProfile>(
      studentProfileEntries.vals(),
      1,
      Principal.equal,
      Principal.hash,
    );
  };
  // STEP 1 - END

  // STEP 2 - BEGIN
  type calculatorInterface = Type.CalculatorInterface;
  public type TestResult = Type.TestResult;
  public type TestError = Type.TestError;

  public shared func test(canisterId : Principal) : async TestResult {
    var res : Int = 0;
    let calculatorCanister = actor (Principal.toText(canisterId)) : Type.CalculatorInterface;
    try {
      switch (await calculatorCanister.reset()) {
        case (0) {
          switch (await calculatorCanister.add(8)) {
            case (8) {
              switch (await calculatorCanister.sub(3)) {
                case (5) return #ok();
                case (_) {
                  return #err(#UnexpectedValue("sub method returned unexpected value"));
                };
              };
            };
            case (_) {
              return #err(#UnexpectedValue("add method returned unexpected value"));
            };
          };
        };
        case (_) {
          return #err(#UnexpectedValue("reset method returned non-zero value"));
        };
      };
      return #ok();
    } catch (e) {
      return #err(#UnexpectedError("not implemented"));
    };
  };
  // STEP - 2 END

  // STEP 3 - BEGIN
  // NOTE: Not possible to develop locally,
  // as actor "aaaa-aa" (aka the IC itself, exposed as an interface) does not exist locally
  let IC_id = "aaaaa-aa";
  let ic = actor (IC_id) : IC.ManagementCanisterInterface;

  private func parseControllersFromCanisterStatusErrorIfCallerNotController(errorMessage : Text) : async [Principal] {
    let lines = Iter.toArray(Text.split(errorMessage, #text("\n")));
    let words = Iter.toArray(Text.split(lines[1], #text(" ")));
    var i = 2;
    let controllers = Buffer.Buffer<Principal>(0);
    while (i < words.size()) {
      controllers.add(Principal.fromText(words[i]));
      i += 1;
    };
    Buffer.toArray<Principal>(controllers);
  };

  public shared func verifyOwnership(canisterId : Principal, p : Principal) : async Bool {
    var controllers : [Principal] = [];
    try {
      let canisterStatus = await ic.canister_status({ canister_id = canisterId });
      controllers := canisterStatus.settings.controllers;
    } catch (err) {
      controllers := await parseControllersFromCanisterStatusErrorIfCallerNotController(
        Error.message(err)
      );
    };

    for (controller in controllers.vals()) {
      if (Principal.equal(controller, p)) return true;
    };
    return false;
  };
  // STEP 3 - END

  // STEP 4 - BEGIN
  public shared ({ caller }) func verifyWork(canisterId : Principal, p : Principal) : async Result.Result<(), Text> {
    let ownership = await verifyOwnership(canisterId, p);
    let res = await test(canisterId);
    if (ownership and Result.isOk(res)) {
      switch (studentProfileStore.get(caller)) {
        case null return #err("student not found");
        case (?student) {
          let s = { name = student.name; team = student.team; graduate = true };
          studentProfileStore.put(p, s);
          return #ok();
        };
      };
    };
    return #err("failed verification");
  };
  // STEP 4 - END
};
