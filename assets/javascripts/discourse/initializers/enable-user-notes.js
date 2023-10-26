import { withPluginApi } from "discourse/lib/plugin-api";
import { iconNode } from "discourse-common/lib/icon-library";
import { showUserNotes } from "discourse/plugins/discourse-user-notes/discourse-user-notes/lib/user-notes";
import { observes, on } from "discourse-common/utils/decorators";

const PLUGIN_ID = "discourse-user-notes";

export default {
  name: "enable-user-notes",
  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    const currentUser = container.lookup("current-user:main");
    const appEvents = container.lookup("service:app-events");

    if (
      !siteSettings.user_notes_enabled ||
      !currentUser ||
      !currentUser.staff
    ) {
      return;
    }

    const store = container.lookup("service:store");
    withPluginApi("0.8.15", (api) => {
      function widgetshowUserNotes() {
        showUserNotes(
          store,
          this.attrs.user_id,
          (count) => {
            this.sendWidgetAction("refreshUserNotes", count);
          },
          {
            postId: this.attrs.id,
          }
        );
      }

      api.attachWidgetAction("post", "refreshUserNotes", function (count) {
        const cfs = this.model.user_custom_fields || {};
        cfs.user_notes_count = count;
        this.model.set("user_custom_fields", cfs);
      });

      api.modifyClass("controller:user", {
        pluginId: PLUGIN_ID,
        userNotesCount: null,

        @on("init")
        @observes("model")
        _modelChanged: function () {
          this.set(
            "userNotesCount",
            this.get("model.custom_fields.user_notes_count") || 0
          );
        },

        actions: {
          showUserNotes() {
            showUserNotes(store, this.model.id, (count) =>
              this.set("userNotesCount", count)
            );
          },
        },
      });

      const mobileView = api.container.lookup("site:main").mobileView;
      const loc = mobileView ? "before" : "after";
      api.decorateWidget(`poster-name:${loc}`, (dec) => {
        if (dec.widget.settings.hideNotes) {
          return;
        }

        const post = dec.getModel();
        if (!post) {
          return;
        }

        const ucf = post.user_custom_fields || {};
        if (ucf.user_notes_count > 0) {
          return dec.attach("user-notes-icon");
        }
      });

      api.decorateWidget(`post-avatar:after`, (dec) => {
        if (!dec.widget.settings.showNotes) {
          return;
        }

        const post = dec.getModel();
        if (!post) {
          return;
        }

        const ucf = post.user_custom_fields || {};
        if (ucf.user_notes_count > 0) {
          return dec.attach("user-notes-icon");
        }
      });
      api.addPostAdminMenuButton((attrs) => {
        return {
          icon: "pencil-alt",
          label: "user_notes.attach",
          action: (post) => {
            showUserNotes(
              store,
              attrs.user_id,
              (count) => {
                const ucf = post.user_custom_fields || {};
                ucf.user_notes_count = count;
                post.set("user_custom_fields", ucf);

                appEvents.trigger("post-stream:refresh", {
                  id: post.id,
                });
              },
              { postId: attrs.id }
            );
          },
          secondaryAction: "closeAdminMenu",
          className: "add-user-note",
        };
      });

      api.attachWidgetAction("post", "showUserNotes", widgetshowUserNotes);

      api.createWidget("user-notes-icon", {
        tagName: "span.user-notes-icon",
        click: widgetshowUserNotes,

        html() {
          if (siteSettings.enable_emoji) {
            return this.attach("emoji", { name: "pencil" });
          } else {
            return iconNode("sticky-note");
          }
        },
      });
    });
  },
};
