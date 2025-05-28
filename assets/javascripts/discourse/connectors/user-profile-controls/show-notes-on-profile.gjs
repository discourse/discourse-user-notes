import Component from "@ember/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { classNames, tagName } from "@ember-decorators/component";
import ShowUserNotes from "../../components/show-user-notes";
import { showUserNotes } from "../../lib/user-notes";

@tagName("li")
@classNames("user-profile-controls-outlet", "show-notes-on-profile")
export default class ShowNotesOnProfile extends Component {
  static shouldRender(args, context) {
    const { siteSettings, currentUser } = context;
    return siteSettings.user_notes_enabled && currentUser && currentUser.staff;
  }

  init() {
    super.init(...arguments);
    const { model } = this;
    this.set(
      "userNotesCount",
      model.user_notes_count || model.get("custom_fields.user_notes_count") || 0
    );
  }

  @action
  showUserNotes() {
    const store = getOwner(this).lookup("service:store");
    const user = this.get("args.model");
    showUserNotes(store, user.id, (count) => this.set("userNotesCount", count));
  }

  <template>
    <ShowUserNotes
      @show={{action "showUserNotes"}}
      @count={{this.userNotesCount}}
    />
  </template>
}
