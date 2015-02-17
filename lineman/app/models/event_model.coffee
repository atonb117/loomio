angular.module('loomioApp').factory 'EventModel', (BaseModel) ->
  class EventModel extends BaseModel
    @singular: 'event'
    @plural: 'events'

    membershipRequest: ->
      @recordStore.membershipRequests.find(@membershipRequestId)

    discussion: ->
      @recordStore.discussions.find(@discussionId)

    comment: ->
      @recordStore.comments.find(@commentId)

    proposal: ->
      @recordStore.proposals.find(@proposalId)

    vote: ->
      @recordStore.votes.find(@voteId)

    actor: ->
      @recordStore.users.find(@actorId)

    link: ->
      switch @kind
        when 'comment_liked' then "/discussions/#{@comment().discussion().key}##{@commentId}"
