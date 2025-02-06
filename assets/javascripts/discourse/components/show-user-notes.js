import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class ShowUserNotes extends Component {
  get label() {
    if (this.args.count > 0) {
      return i18n("user_notes.show", { count: this.args.count });
    } else {
      return i18n("user_notes.title");
    }
  }
}
