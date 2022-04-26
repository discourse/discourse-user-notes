import I18n from "I18n";
import { showUserNotes } from "discourse/plugins/discourse-user-notes/discourse-user-notes/lib/user-notes";
import { getOwner } from "discourse-common/lib/get-owner";
import { emojiUrlFor } from "discourse/lib/text";
import EmberObject from "@ember/object";

export default {
  shouldRender(args, component) {
    return component.siteSettings.user_notes_enabled && args.user;
  },

  setupComponent(args, component) {
    const model = EmberObject.create(args.user);
    const userNotesCount = model.get("custom_fields.user_notes_count") || 0;
    component.setProperties({
      userNotesCount,
      emojiEnabled: component.siteSettings.enable_emoji,
      emojiUrl: emojiUrlFor("pencil"),
      userNotesTitle: I18n.t("user_notes.show", { count: userNotesCount }),
    });
  },

  actions: {
    showUserNotes() {
      const store = getOwner(this).lookup("service:store");
      const user = this.get("args.user");
      showUserNotes(store, user.id, (count) =>
        this.set("userNotesCount", count)
      );
    },
  },
};
