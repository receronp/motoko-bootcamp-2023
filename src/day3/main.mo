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

  private stable var messageId : Nat = 0;
  private stable var wallEntries : [(Text, Message)] = [];
  private var wall = HashMap.HashMap<Text, Message>(1, Text.equal, Text.hash);

  system func preupgrade() {
    wallEntries := Iter.toArray(wall.entries());
  };

  system func postupgrade() {
    wall := HashMap.fromIter<Text, Message>(
      wallEntries.vals(),
      1,
      Text.equal,
      Text.hash,
    );
  };

  public shared ({ caller }) func writeMessage(c : Content) : async Nat {
    let index = messageId;
    let message : Message = {
      id = index;
      content = c;
      vote = 0;
      creator = caller;
    };
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
        id = message.id;
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
      id = message.id;
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

  func toSurvey(c : Content) : Survey {
    switch c {
      case (#Survey { title; answers }) {
        return {
          title = title;
          answers = answers;
        };
      };
      case (_) return { title = ""; answers = [] };
    };
  };

  func updateSurvey(messageId : Nat, message : Message, survey : Survey, buf : Buffer.Buffer<Answer>) : () {
    let s = {
      title = survey.title;
      answers = Buffer.toArray<Answer>(buf);
    };

    let m = {
      id = message.id;
      content = #Survey s;
      vote = message.vote;
      creator = message.creator;
    };

    wall.put(Nat.toText(messageId), m);
    return;
  };

  public shared func surveyAnswer(messageId : Nat, answer : Answer) : async Result.Result<(), Text> {
    var message : Message = switch (wall.get(Nat.toText(messageId))) {
      case null return #err("Invalid message ID");
      case (?result) result;
    };

    var survey : Survey = toSurvey(message.content);

    switch (survey.title) {
      case "" return #err("Message does not contain survey");
      case (_) {
        let buf = Buffer.fromArray<Answer>(survey.answers);
        buf.add(answer);
        updateSurvey(messageId, message, survey, buf);
        return #ok();
      };
    };
  };

  public shared func surveyVote(messageId : Nat, answer_index : Nat) : async Result.Result<(), Text> {
    var message : Message = switch (wall.get(Nat.toText(messageId))) {
      case null return #err("Invalid message ID");
      case (?result) result;
    };

    var survey : Survey = toSurvey(message.content);

    switch (survey.title) {
      case "" return #err("Message does not contain survey");
      case (_) {
        let buf = Buffer.fromArray<Answer>(survey.answers);
        switch (buf.getOpt(answer_index)) {
          case null return #err("Index out of bounds for this survey");
          case (?answer) {
            buf.put(answer_index, (answer.0, answer.1 + 1));
            updateSurvey(messageId, message, survey, buf);
            return #ok();
          };
        };
      };
    };
  };
};
