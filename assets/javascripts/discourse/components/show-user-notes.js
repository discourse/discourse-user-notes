import Component from "@glimmer/component";
import I18n from "I18n";

export default class ShowUserNotes extends Component {
  get label() {
    if (this.args.count > 0) {
      return I18n.t("user_notes.show", { count: this.args.count });
    } else {
      return I18n.t("user_notes.title");
    }
  }
}
