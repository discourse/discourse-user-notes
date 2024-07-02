import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { emojiUrlFor } from "discourse/lib/text";
import icon from "discourse-common/helpers/d-icon";
import I18n from "I18n";
import { showUserNotes } from "discourse/plugins/discourse-user-notes/discourse-user-notes/lib/user-notes";

export default class extends Component {
  static shouldRender(args, context) {
    const { siteSettings, currentUser } = context;
    return siteSettings.user_notes_enabled && currentUser?.staff;
  }

  @service siteSettings;
  @service currentUser;
  @service store;

  get userNotesCount() {
    return parseInt(
      this.args.outletArgs.user.get("user_notes_count") ||
        this.args.outletArgs.user.get("custom_fields.user_notes_count") ||
        0,
      10
    );
  }

  @action
  showUserNotes() {
    showUserNotes(this.store, this.args.outletArgs.user.id);
  }

  <template>
    <div class="show-user-notes-on-card">
      {{#if this.userNotesCount}}
        <DButton
          @translatedTitle={{I18n.t
            "user_notes.show"
            count=this.userNotesCount
          }}
          @action={{this.showUserNotes}}
          class="btn btn-flat"
        >
          {{#if this.siteSettings.enable_emoji}}
            <img src={{emojiUrlFor "pencil"}} alt="pencil" class="emoji" />
          {{else}}
            {{icon "sticky-note"}}
          {{/if}}
        </DButton>
      {{/if}}
    </div>
  </template>
}
