import { getOwner } from "discourse-common/lib/get-owner";
import { showUserNotes } from "discourse/plugins/discourse-user-notes/discourse-user-notes/lib/user-notes";

export default {
  shouldRender(args, component) {
    const { siteSettings, currentUser } = component;
    return siteSettings.user_notes_enabled && currentUser && currentUser.staff;
  },

  setupComponent(args, component) {
    const { model } = args;
    component.set(
      "userNotesCount",
      model.user_notes_count || model.get("custom_fields.user_notes_count") || 0
    );
  },

  actions: {
    showUserNotes() {
      const store = getOwner(this).lookup("service:store");
      const user = this.get("args.model");
      showUserNotes(store, user.id, (count) =>
        this.set("userNotesCount", count)
      );
    },
  },
};
