import { iconNode } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { showUserNotes } from "../lib/user-notes";

export default {
  name: "enable-user-notes",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");
    const appEvents = container.lookup("service:app-events");

    if (!siteSettings.user_notes_enabled || !currentUser?.staff) {
      return;
    }

    const store = container.lookup("service:store");

    withPluginApi("0.8.15", (api) => {
      function widgetShowUserNotes() {
        showUserNotes(
          this.store,
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

      const mobileView = api.container.lookup("service:site").mobileView;
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
          icon: "pen-to-square",
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

      api.attachWidgetAction("post", "showUserNotes", widgetShowUserNotes);

      api.createWidget("user-notes-icon", {
        services: ["site-settings"],

        tagName: "span.user-notes-icon",
        click: widgetShowUserNotes,

        html() {
          if (this.siteSettings.enable_emoji) {
            return this.attach("emoji", { name: "memo" });
          } else {
            return iconNode("pen-to-square");
          }
        },
      });
    });
  },
};
