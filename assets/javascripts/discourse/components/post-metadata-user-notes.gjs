import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";

export default class PostMetadataUserNotes extends Component {
  @service siteSettings;

  <template>{{icon "pen-to-square"}}</template>
}
