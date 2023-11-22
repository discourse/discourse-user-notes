import UserNotesModal from "../../discourse/components/modal/user-notes";
import { getOwner } from "discourse-common/lib/get-owner";

export function showUserNotes(store, userId, callback, opts) {
  const modal = getOwner(this).lookup("service:modal");
  opts = opts || {};

  return store.find("user-note", { user_id: userId }).then((model) => {
    return modal.show(UserNotesModal, {
      model: {
        note: model,
        userId,
        callback,
        postId: opts.postId,
      },
    });
  });
}
