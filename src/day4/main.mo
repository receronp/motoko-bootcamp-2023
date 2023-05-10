import TrieMap "mo:base/TrieMap";
import Trie "mo:base/Trie";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Debug "mo:base/Debug";

import Account "Account";

actor class MotoCoin() {
  public type Account = Account.Account;
  let ledger = TrieMap.TrieMap<Account, Nat>(Account.accountsEqual, Account.accountsHash);

  let bootcampCanister = actor ("rww3b-zqaaa-aaaam-abioa-cai") : actor {
    getAllStudentsPrincipal : shared () -> async [Principal];
  };

  public shared query func name() : async Text {
    return "MotoCoin";
  };

  public shared query func symbol() : async Text {
    return "MOC";
  };

  public shared query func totalSupply() : async Nat {
    var total = 0;
    for (balance in ledger.vals()) {
      total += balance;
    };
    return total;
  };

  public shared query func balanceOf(account : Account) : async (Nat) {
    switch (ledger.get(account)) {
      case null 0;
      case (?result) result;
    };
  };

  public shared func transfer(
    from : Account,
    to : Account,
    amount : Nat,
  ) : async Result.Result<(), Text> {
    switch (ledger.get(from)) {
      case null return #err("Invalid from account");
      case (?fromBalance) {
        switch (ledger.get(to)) {
          case null return #err("Invalid to account");
          case (?toBalance) {
            if (fromBalance >= amount) {
              ledger.put(from, fromBalance - amount);
              ledger.put(to, toBalance + amount);
              return #ok;
            } else {
              return #err("Insufficient funds");
            };
          };
        };
      };
    };
  };

  public shared func airdrop() : async Result.Result<(), Text> {
    let students = await bootcampCanister.getAllStudentsPrincipal();
    for (student in students.vals()) {
      let account : Account = { owner = student; subaccount = null };
      switch (ledger.get(account)) {
        case (?value) { return #err("Airdrop already completed") };
        case (null) { ledger.put(account, 100) };
      };
    };
    return #ok();
  };
};
