import Type "Types";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Int "mo:base/Int";

actor class StudentWall() {
  type Message = Type.Message;
  type Content = Type.Content;
  type Survey = Type.Survey;
  type Answer = Type.Answer;

  var messageId : Nat = 0;
  let wall = HashMap.HashMap<Text, Message>(1, Text.equal, Text.hash);

  public shared ({ caller }) func writeMessage(c : Content) : async Nat {
    let message : Message = {
      content = c;
      vote = 0;
      creator = caller;
    };
    let index = messageId;
    wall.put(Nat.toText(index), message);
    messageId += 1;
    return index;
  };

  public shared query func getMessage(messageId : Nat) : async Result.Result<Message, Text> {
    switch (wall.get(Nat.toText(messageId))) {
      case null #err("Invalid message ID");
      case (?result) #ok(result);
    };
  };

  public shared ({ caller }) func updateMessage(messageId : Nat, c : Content) : async Result.Result<(), Text> {
    var message : Message = switch (wall.get(Nat.toText(messageId))) {
      case null return #err("Invalid message ID");
      case (?result) result;
    };

    if (Principal.equal(message.creator, caller)) {
      message := {
        content = c;
        vote = message.vote;
        creator = message.creator;
      };
      wall.put(Nat.toText(messageId), message);
      return #ok();
    } else {
      return #err("Invalid message ID");
    };
  };

  public shared func deleteMessage(messageId : Nat) : async Result.Result<(), Text> {
    switch (wall.remove(Nat.toText(messageId))) {
      case null #err("Invalid message ID");
      case (?result) #ok();
    };
  };

  private func addVote(messageId : Nat, message : Message, vote : Int) : () {
    let m = {
      content = message.content;
      vote = message.vote + vote;
      creator = message.creator;
    };
    wall.put(Nat.toText(messageId), m);
  };

  public shared func upVote(messageId : Nat) : async Result.Result<(), Text> {
    var message : Message = switch (wall.get(Nat.toText(messageId))) {
      case null return #err("Invalid message ID");
      case (?result) result;
    };

    addVote(messageId, message, 1);
    return #ok();
  };

  public shared func downVote(messageId : Nat) : async Result.Result<(), Text> {
    var message : Message = switch (wall.get(Nat.toText(messageId))) {
      case null return #err("Invalid message ID");
      case (?result) result;
    };

    addVote(messageId, message, -1);
    return #ok();
  };

  public query func getAllMessages() : async [Message] {
    var messages = List.nil<Message>();
    for (message in wall.vals()) {
      messages := List.push(message, messages);
    };
    return List.toArray(messages);
  };

  public query func getAllMessagesRanked() : async [Message] {
    var messages = List.nil<Message>();
    for (message in wall.vals()) {
      messages := List.push(message, messages);
    };
    var msgArr = List.toArray(messages);
    Array.sort<Message>(
      msgArr,
      func(a : Message, b : Message) {
        if (a.vote > b.vote) { #less } else if (a.vote == b.vote) { #equal } else {
          #greater;
        };
      },
    );
  };
};
