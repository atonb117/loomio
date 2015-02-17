angular.module('loomioApp').factory 'DiscussionReaderModel', (BaseModel) ->
  class DiscussionReaderModel extends BaseModel
    @singular: 'discussion_reader'
    @plural: 'discussion_readers'

    initialize: (data) ->
      @baseInitialize(data)
      @id = data.discussion_id

    serialize: ->
      data = @baseSerialize()
      data.discussion_id = @id
      data

    markItemAsRead: (item) ->
      @lastReadSequenceId = item.sequenceId
      @lastReadAt = item.createdAt

