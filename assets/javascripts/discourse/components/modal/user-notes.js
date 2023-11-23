import Component from "@glimmer/component";
import I18n from "I18n";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { tracked } from "@glimmer/tracking";

export default class UserNotesModal extends Component {
  @service dialog;
  @service store;

  @tracked newNote;
  @tracked userId = this.args.model.userId;
  @tracked saving = false;
  postId = this.args.model.postId;
  callback = this.args.model.callback;

  #refreshCount() {
    if (this.callback) {
      this.callback(this.args.model.note.length);
    }
  }

  get attachDisabled() {
    return this.saving || !this.newNote || this.newNote.length === 0;
  }

  @action
  async attachNote() {
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

    try {
      await note.save(args);
      this.newNote = "";
      this.args.model.note.insertAt(0, note);
      this.#refreshCount();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  removeNote(note) {
    this.dialog.deleteConfirm({
      message: I18n.t("user_notes.delete_confirm"),
      didConfirm: () => {
        note
          .destroyRecord()
          .then(() => {
            this.args.model.note.removeObject(note);
            this.#refreshCount();
          })
          .catch(popupAjaxError);
      },
    });
  }
}
