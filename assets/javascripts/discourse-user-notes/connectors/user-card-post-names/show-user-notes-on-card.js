import { emojiUrlFor } from "discourse/lib/text";
import { getOwner } from "discourse-common/lib/get-owner";
import I18n from "I18n";
import { showUserNotes } from "discourse/plugins/discourse-user-notes/discourse-user-notes/lib/user-notes";

export default {
  shouldRender(args, component) {
    const { siteSettings, currentUser } = component;
    return siteSettings.user_notes_enabled && currentUser && currentUser.staff;
  },

  setupComponent(args, component) {
    const { user } = args;
    const count =
      user.user_notes_count || user.get("custom_fields.user_notes_count") || 0;

    component.setProperties({
      userNotesCount: count,
      emojiEnabled: component.siteSettings.enable_emoji,
      emojiUrl: emojiUrlFor("pencil"),
      userNotesTitle: I18n.t("user_notes.show", { count }),
    });
  },

  actions: {
    showUserNotes() {
      this.parentView.parentView._close();
      const store = getOwner(this).lookup("service:store");
      const user = this.get("args.user");
      showUserNotes(store, user.id, (count) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("userNotesCount", count);
      });
    },
  },
};
