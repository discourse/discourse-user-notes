import I18n from "I18n";
import {
  default as discourseComputed,
  on,
} from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Controller from "@ember/controller";

export default Controller.extend({
  newNote: null,
  saving: false,
  user: null,

  @on("init")
  reset() {
    this.setProperties({ newNote: null, saving: false, callback: null });
  },

  @discourseComputed("newNote", "saving")
  attachDisabled(newNote, saving) {
    return saving || !newNote || newNote.length === 0;
  },

  _refreshCount() {
    if (this.callback) {
      this.callback(this.get("model.length"));
    }
  },

  actions: {
    attachNote() {
      const note = this.store.createRecord("user-note");
      const userId = parseInt(this.userId, 10);

      this.set("saving", true);
      let args = {
        raw: this.newNote,
        user_id: userId,
      };

      if (this.postId) {
        args.post_id = parseInt(this.postId, 10);
      }

      note
        .save(args)
        .then(() => {
          this.set("newNote", "");
          this.model.insertAt(0, note);
          this._refreshCount();
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    },

    removeNote(note) {
      bootbox.confirm(
        I18n.t("user_notes.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        (result) => {
          if (result) {
            note
              .destroyRecord()
              .then(() => {
                this.model.removeObject(note);
                this._refreshCount();
              })
              .catch(popupAjaxError);
          }
        }
      );
    },
  },
});
