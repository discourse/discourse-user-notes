import Controller from "@ember/controller";
import I18n from "I18n";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { tracked } from "@glimmer/tracking";

export default class UserNotesController extends Controller {
  @service dialog;

  @tracked newNote;
  @tracked userId;
  @tracked saving = false;

  #refreshCount() {
    if (this.callback) {
      this.callback(this.model.length);
    }
  }

  reset() {
    this.newNote = null;
    this.userId = null;
    this.callback = null;
    this.saving = false;
  }

  get attachDisabled() {
    return this.saving || !this.newNote || this.newNote.length === 0;
  }

  @action
  attachNote() {
    const note = this.store.createRecord("user-note");
    const userId = parseInt(this.userId, 10);

    this.saving = true;

    const args = {
      raw: this.newNote,
      user_id: userId,
    };

    if (this.postId) {
      args.post_id = parseInt(this.postId, 10);
    }

    note
      .save(args)
      .then(() => {
        this.newNote = "";
        this.model.insertAt(0, note);
        this.#refreshCount();
      })
      .catch(popupAjaxError)
      .finally(() => (this.saving = false));
  }

  @action
  removeNote(note) {
    this.dialog.deleteConfirm({
      message: I18n.t("user_notes.delete_confirm"),
      didConfirm: () => {
        note
          .destroyRecord()
          .then(() => {
            this.model.removeObject(note);
            this.#refreshCount();
          })
          .catch(popupAjaxError);
      },
    });
  }
}
