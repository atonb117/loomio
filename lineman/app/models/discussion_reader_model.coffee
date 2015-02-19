angular.module('loomioApp').factory 'DiscussionReaderModel', (BaseModel) ->
  class DiscussionReaderModel extends BaseModel
    @singular: 'discussion_reader'
    @plural: 'discussion_readers'

    initialize: (data) ->
      @readItemsCount = 0
      @readCommentsCount = 0
      @lastReadAt = null
      @following = null
      @lastReadSequenceId = 0

      @baseInitialize(data)
      @id = data.discussion_id

    serialize: ->
      data = @baseSerialize()
      data.discussion_id = @id
      data

    markItemAsRead: (item) ->
      @lastReadSequenceId = item.sequenceId
      @lastReadAt = item.createdAt

