import { showUserNotes } from "discourse/plugins/discourse-user-notes/discourse-user-notes/lib/user-notes";
import { getOwner } from "discourse-common/lib/get-owner";

export default {
  shouldRender(args, component) {
    return component.siteSettings.user_notes_enabled;
  },

  setupComponent(args, component) {
    const model = args.flaggedPost.user;
    component.set(
      "userNotesCount",
      model.get("custom_fields.user_notes_count") || 0
    );
  },

  actions: {
    showUserNotes() {
      const store = getOwner(this).lookup("store:main");
      const user = this.get("args.flaggedPost.user");
      showUserNotes(store, user.id, count =>
        this.set("userNotesCount", count)
      );
    }
  }
};
