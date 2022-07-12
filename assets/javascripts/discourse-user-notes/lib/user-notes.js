import showModal from "discourse/lib/show-modal";

export function showUserNotes(store, userId, callback, opts) {
  opts = opts || {};

  return store.find("user-note", { user_id: userId }).then((model) => {
    const controller = showModal("user-notes", {
      model,
      title: "user_notes.title",
      addModalBodyView: true,
    });
    controller.reset();

    controller.setProperties({
      userId,
      callback,
      postId: opts.postId,
    });

    return controller;
  });
}
