import Component from "@glimmer/component";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { iconNode } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { applyValueTransformer } from "discourse/lib/transformer";
import PostMetadataUserNotes from "../components/post-metadata-user-notes";
import { showUserNotes } from "../lib/user-notes";

export default {
  name: "enable-user-notes",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");

    if (!siteSettings.user_notes_enabled || !currentUser?.staff) {
      return;
    }

    withPluginApi((api) => {
      customizePost(api, container);
      customizePostMenu(api, container);
    });
  },
};

function customizePost(api, container) {
  const siteSettings = container.lookup("service:site-settings");

  const iconPlacement = applyValueTransformer(
    "user-notes-icon-placement",
    siteSettings.user_notes_icon_placement
  );

  if (iconPlacement === "name") {
    api.renderBeforeWrapperOutlet(
      "post-meta-data-poster-name",
      class extends Component {
        static shouldRender(args, context) {
          return context.site.mobileView;
        }

        <template><PostMetadataUserNotes @post={{@post}} /></template>
      }
    );

    api.renderAfterWrapperOutlet(
      "post-meta-data-poster-name",
      class extends Component {
        static shouldRender(args, context) {
          return !context.site.mobileView;
        }

        <template><PostMetadataUserNotes @post={{@post}} /></template>
      }
    );
  } else if (iconPlacement === "avatar") {
    api.renderAfterWrapperOutlet("poster-avatar", PostMetadataUserNotes);
  }

  withSilencedDeprecations("discourse.post-stream-widget-overrides", () =>
    customizeWidgetPost(api)
  );
}

function customizeWidgetPost(api) {
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
}

function customizePostMenu(api, container) {
  const appEvents = container.lookup("service:app-events");
  const store = container.lookup("service:store");

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
}
