import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Array "mo:base/Array";

import Type "Types";
import Time "mo:base/Time";
import Bool "mo:base/Bool";
import Text "mo:base/Text";

actor class Homework() {
  type Homework = Type.Homework;
  var homeworkDiary = Buffer.Buffer<Homework>(5);

  public shared func addHomework(homework : Homework) : async Nat {
    let index = homeworkDiary.size();
    homeworkDiary.add(homework);
    return index;
  };

  public shared query func getHomework(id : Nat) : async Result.Result<Homework, Text> {
    switch (homeworkDiary.getOpt(id)) {
      case null #err("Invalid homework ID");
      case (?result) #ok(result);
    };
  };

  public shared func updateHomework(id : Nat, homework : Homework) : async Result.Result<(), Text> {
    var hw = switch (homeworkDiary.put(id, homework)) {
      case (result) return #ok();
    };
    return #err("Invalid homework ID");
  };

  public shared func deleteHomework(id : Nat) : async Result.Result<(), Text> {
    switch (homeworkDiary.remove(id)) {
      case (result) return #ok();
    };
    return #err("Invalid homework ID");
  };

  public shared query func getAllHomework() : async [Homework] {
    return Buffer.toArray<Homework>(homeworkDiary);
  };

  public shared func markAsCompleted(id : Nat) : async Result.Result<(), Text> {
    switch (homeworkDiary.getOpt(id)) {
      case null return #err("Invalid homework ID");
      case (?result) {
        let homeworkComplete : Homework = {
          title = result.title;
          description = result.description;
          dueDate = result.dueDate;
          completed = true;
        };
        homeworkDiary.put(id, homeworkComplete);
        return #ok();
      };
    };
  };

  public shared query func getPendingHomework() : async [Homework] {
    return Array.filter<Homework>(Buffer.toArray(homeworkDiary), func x = Bool.lognot(x.completed));
  };

  public shared query func searchHomework(searchTerm : Text) : async [Homework] {
    return Array.filter<Homework>(
      Buffer.toArray(homeworkDiary),
      func x = Bool.logor(
        Text.contains(x.title, #text searchTerm),
        Text.contains(x.description, #text searchTerm),
      ),
    );
  };
};
