describe 'DiscussionModel', ->
  discussion = null
  discussionReader = null
  author = null
  recordStore = null
  proposal = null
  group = null
  event = null
  otherEvent = null
  comment = null

  beforeEach module 'loomioApp'

  beforeEach ->
    inject (Records) ->
      recordStore = Records

    group = recordStore.groups.initialize(id: 1, name: 'group')
    discussion = recordStore.discussions.initialize(id: 1, group_id: group.id, title: 'Hi')
    author = recordStore.users.initialize(id: 1, name: 'Sam')
    event = recordStore.events.initialize(id: 1, sequence_id: 1, discussion_id: 1)
    otherEvent = recordStore.events.initialize(id: 2, sequence_id: 2, discussion_id: 2)
    discussionReader = recordStore.discussionReaders.initialize(discussion_id: 1)

  describe 'author()', ->
    it 'returns the discussion author', ->
      discussion.authorId = author.id
      expect(discussion.author()).toBe(author)

  describe 'comments()', ->
    beforeEach ->
      comment = recordStore.comments.initialize(id:5, discussion_id: discussion.id)

    it 'returns comments', ->
      expect(discussion.comments()).toContain(comment)

  describe 'proposals()', ->
    beforeEach ->
      proposal = recordStore.proposals.initialize(id:7, discussion_id: discussion.id)
      #proposal = recordStore.proposals.initialize(id:7, discussion_id: discussion.id)
      #proposal = recordStore.proposals.initialize(id:7, discussion_id: discussion.id)
      #console.log proposal
      #console.log _.map(discussion.proposals(), (p) -> p.id)

    it 'returns proposals', ->
      expect(discussion.proposals()).toContain(proposal)
      expect(discussion.proposals().length).toBe(1)

  describe 'group()', ->
    it 'returns its group', ->
      expect(discussion.group()).toBe(group)

  describe 'events()', ->
    it 'returns events for the discussion', ->
      expect(discussion.events()).toContain(event)

    it 'does not return events for another discussion', ->
      expect(discussion.events()).not.toContain(otherEvent)

  describe 'reader', ->
    it "returns the discussion reader associated with this discussion", ->
      expect(discussion.reader()).toBe(discussionReader)

  describe 'lastActivityAt', ->
    it 'returns created at when no vote or comments', ->
      expect(discussion.lastActivityAt()).toBe(discussion.createdAt)

    it 'returns last vote at when proposal last vote at is most recent', ->
      propoal.lastVoteAt = "2015-02-12T01:17:44.477Z"
      expect(discussion.lastActivityAt()).toBe(proposal.lastVoteAt)

    it 'returns last comment at when last comment at is most recent', ->
      discussion.lastCommentAt = "2015-02-12T01:17:44.477Z"
      expect(discussion.lastActivityAt()).toBe(discussion.lastCommentAt)

