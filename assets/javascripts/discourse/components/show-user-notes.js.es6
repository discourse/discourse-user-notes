export default Ember.Component.extend({
  tagName: "",

  showCount: Ember.computed.gt("count", 0)
});
