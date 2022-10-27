import I18n from "I18n";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Controller from "@ember/controller";
import { inject as service } from "@ember/service";

export default Controller.extend({
  dialog: service(),
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
      this.dialog.deleteConfirm({
        message: I18n.t("user_notes.delete_confirm"),
        didConfirm: () => {
          note
            .destroyRecord()
            .then(() => {
              this.model.removeObject(note);
              this._refreshCount();
            })
            .catch(popupAjaxError);
        },
      });
    },
  },
});
