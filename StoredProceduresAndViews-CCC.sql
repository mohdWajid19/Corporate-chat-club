CREATE VIEW InactiveClub AS 
SELECT *, 
	(SELECT u.DisplayName FROM [User] u WHERE u.Id = c.OwnerId) AS CreatedByName, 
	(SELECT DisplayName FROM [User] u WHERE u.Id = c.ActionTakenBy) AS DeactivatedByName
FROM Club c WHERE c.[Status] = 1;

GO

CREATE   VIEW [dbo].[UserClubDetails] AS

SELECT *,

(SELECT [DisplayName] FROM [dbo].[User] [AddedByUser] WHERE [AddedByUser].[Id] = [U].[AddedBy]) AS [AddedByUserName],

(SELECT COUNT(*) FROM [dbo].[UserClub] [UC] WHERE [UC].[UserId] = [U].[Id]) AS [ActiveClubsCount]

FROM [dbo].[User] [U];

GO

CREATE  VIEW dbo.[UserDetails] AS
SELECT B.Id,B.FirstName,B.MiddleName,B.LastName,B.DisplayName,B.Phone,B.Email,B.[Status],B.ActionTakenBy,B.ActionTakenOn,B.Reason,B.IsDeleted,B.AddedBy,B.AddedOn,B.[Role],A.ProfileImageUrl,A.Gender,A.DOB,A.BloodGroup,A.About,A.[Address],A.ProfessionalSummary
	FROM dbo.[UserProfile] A 
	LEFT JOIN dbo.[User] B ON A.UserId = B.Id;


GO
-- STORED PROCEDURES --

CREATE   PROCEDURE [dbo].[GetAllClubs] 
	@userId UNIQUEIDENTIFIER
 AS
 BEGIN 
	 SELECT [c].[Id], [c].[IconUrl], [c].[Title], [c].[OwnerId], [c].[Visibility], [c].[Type], [c].[Description], [c].[CreatedOn], [Status], [ActionTakenBy], [c].[ActionTakenOn], [c].[Reason], [c].[IsMuted], [c].[IsDeleted]  FROM [dbo].[Club] [c] 
	 JOIN [dbo].[UserClub] [uc] 
	 ON [c].[Id] = [uc].[ClubId] AND [uc].[UserId] = @userId
	 WHERE [uc].[IsDeleted] = 0;
END;

GO


CREATE   PROCEDURE [GetAvailableConnectionDetails]
	@userId UNIQUEIDENTIFIER
AS 
BEGIN 
	DECLARE @availableConnectionId UNIQUEIDENTIFIER;
	DECLARE @name VARCHAR(150);
	DECLARE @profileImageUrl NVARCHAR(MAX);
	DECLARE @mutualClubsCount INT;
	DECLARE @mutualUsersCount INT; 

	CREATE TABLE #TempTable (
	  Id UNIQUEIDENTIFIER,
	  [Name] VARCHAR(150),
	  ProfileImageUrl NVARCHAR(MAX),
	  MutualClubsCount INT,
	  MutualUsersCount INT);
	DECLARE cursor1 CURSOR FOR (SELECT [Id] FROM [User] WHERE [Id] NOT IN ( SELECT [ReceiverId] FROM [Connection] WHERE [SenderId]=@userId AND [IsDeleted] = 0) AND Id<>@userId);
		OPEN cursor1; 
		FETCH NEXT FROM cursor1 INTO @availableConnectionId; 
		WHILE @@FETCH_STATUS = 0 
			BEGIN 
				SET @mutualClubsCount=0;
				SET @mutualUsersCount=0;

				SELECT 
					@name=[u].[DisplayName],@profileImageUrl=[up].[ProfileImageUrl] 
				FROM [User] [u] 
				LEFT JOIN [UserProfile] [up] ON [u].[Id] = [up].[UserId]
				WHERE [u].[Id]=@availableConnectionId;

				SET @mutualClubsCount = (SELECT COUNT(*) FROM [UserClub] [c1] JOIN [UserClub] [c2] ON [c1].[ClubId] = [c2].[ClubId] WHERE [c1].[UserId] = @userId AND [c2].[UserId] = @availableConnectionId);
				SET @mutualUsersCount = (SELECT COUNT(*) FROM [Connection] [f1] JOIN [Connection] [f2] ON [f1].[ReceiverId] = [f2].[ReceiverId] WHERE [f1].[SenderId] = @userId AND [f2].[SenderId] = @availableConnectionId);
				
				INSERT INTO #TempTable VALUES (@availableConnectionId, @name, @profileImageUrl, @mutualClubsCount, @mutualUsersCount); 
				FETCH NEXT FROM cursor1 INTO @availableConnectionId; 
		END; 
		CLOSE cursor1; 
	DEALLOCATE cursor1; 
	SELECT * FROM #TempTable; 
	DROP TABLE #TempTable; 
END;


GO


CREATE   PROCEDURE [GetChatUpdateLogs]
	@clubId UNIQUEIDENTIFIER
AS 
BEGIN 
	SELECT * FROM [dbo].[ClubChatUpdateLog] WHERE [ClubId]=@clubId; 
END;


GO


CREATE    PROCEDURE [dbo].[GetClubChatListItem]
	@userId UNIQUEIDENTIFIER
AS 
BEGIN 
DECLARE @refClubId UNIQUEIDENTIFIER;
DECLARE @title VARCHAR(100);
DECLARE @iconUrl NVARCHAR(MAX);
DECLARE @receiverId UNIQUEIDENTIFIER;
DECLARE @senderId UNIQUEIDENTIFIER;
DECLARE @clubId UNIQUEIDENTIFIER;
DECLARE @id UNIQUEIDENTIFIER;
DECLARE @body NVARCHAR(MAX); 
DECLARE @status tinyint; 
DECLARE @attachments NVARCHAR(MAX); 
DECLARE @timeStamp DATETIME; 
DECLARE @unReadMessageCount INT; 
DECLARE @isFavourite BIT; 
DECLARE @isMuted BIT; 

CREATE TABLE #TempTable (
	  Title VARCHAR(100),
	  IconUrl NVARCHAR(MAX),
	  IsFavourite BIT,
	  IsMuted BIT,
	  UnReadMessageCount INT,
	  Id	 UNIQUEIDENTIFIER,
	  Body NVARCHAR(MAX), 
	  [TimeStamp] DATETIME, 
	  ClubId UNIQUEIDENTIFIER,
	  SenderId UNIQUEIDENTIFIER,
	  ReceiverId UNIQUEIDENTIFIER,
	  [Status] tinyint,
	  Attachments NVARCHAR(MAX));
DECLARE cursor1 CURSOR FOR (SELECT uc.ClubId FROM Club c JOIN  UserClub uc ON c.Id = uc.ClubId AND uc.UserId = @UserId AND uc.IsDeleted = 0);
	OPEN cursor1; 
		FETCH NEXT FROM cursor1 INTO @refClubId; 
		WHILE @@FETCH_STATUS = 0 
			BEGIN 
				SET @id = @refClubId;
				SET @body = null;
				SET @timeStamp = null;
				SET @clubId = @refClubId;
				SET @senderId = null;
				SET @receiverId = null;
				SET @status = 0;
				SET @attachments = null;
				SET @unReadMessageCount = 0;  
				SET @isFavourite = 0;  
				SET @isMuted = 0;  
				SELECT @title=[Title], @iconUrl=[IconUrl] FROM [Club] WHERE Id=@refClubId;
				SELECT TOP 1 
					  @body = Body, 
					  @timeStamp = [TimeStamp], 
					  @senderId = SenderId,
					  @receiverId = ReceiverId,
					  @status = [Status]
				FROM [Message] 
				WHERE ClubId = @refClubId AND ReceiverId=@userId ORDER BY [TimeStamp] DESC; 

				SET @unReadMessageCount = (SELECT COUNT(*) FROM [Message] WHERE ClubId = @refClubId AND ReceiverId=@userId AND [Status] = 0); 
				SELECT @isFavourite = [IsFavourite], @isMuted = IsMuted FROM [UserClub] WHERE [ClubId] = @refClubId AND [UserId]=@userId;

				INSERT INTO #TempTable (
					  Title,
					  IconUrl,
					  IsFavourite,
					  UnReadMessageCount,
					  IsMuted,
					  Id,
					  Body, 
					  [TimeStamp], 
					  ClubId,
					  SenderId,
					  ReceiverId,
					  [Status],
					  Attachments) VALUES (@title, @iconUrl, @isFavourite, @unReadMessageCount, @isMuted, @id, @body, @timeStamp, @clubId, @senderId, @receiverId, @status, @attachments); 
				
				FETCH NEXT FROM cursor1 INTO @refClubId; 
		END; 
	CLOSE cursor1; 
DEALLOCATE cursor1; 
SELECT * FROM #TempTable; 
DROP TABLE #TempTable; 
END;


GO

CREATE PROCEDURE [dbo].[GetClubMemberships]
	@userId UNIQUEIDENTIFIER
AS 
BEGIN 
	DECLARE @clubId UNIQUEIDENTIFIER;
	DECLARE @iconUrl NVARCHAR(MAX);
	DECLARE @title VARCHAR(100);
	DECLARE @description VARCHAR(100);
	DECLARE @isPublic BIT;
	DECLARE @isClosed BIT;
	DECLARE @createdBy VARCHAR(100);
	DECLARE @createdOn DateTime;
	DECLARE @membersCount INT;
	DECLARE @isJoined BIT; 
	DECLARE @isRequested BIT; 

	CREATE TABLE #TempTable (
		  Id UNIQUEIDENTIFIER,
		  IconUrl NVARCHAR(MAX),
		  Title VARCHAR(100),
		  [Description] VARCHAR(100),
		  IsPublic BIT,
		  IsClosed Bit,
		  CreatedBy VARCHAR(100),
		  CreatedOn DateTime,
		  MembersCount INT,
		  IsJoined BIT,
		  IsRequested BIT);
	DECLARE cursor1 CURSOR FOR (SELECT Id FROM Club WHERE IsDeleted=0);
		OPEN cursor1; 
			FETCH NEXT FROM cursor1 INTO @clubId; 
			WHILE @@FETCH_STATUS = 0 
				BEGIN
					SET @membersCount=0;
					SET @isRequested=0;
					SET @isJoined = 0;
					SELECT @iconUrl=[IconUrl], @title=[Title], @description=[Description],@createdOn=[CreatedOn], @isPublic = ~Visibility, @isClosed = [Type] FROM [Club] [c] WHERE [c].[Id]=@clubId;
					SET @createdBy = (SELECT [DisplayName] FROM [User] [u] JOIN [Club] [c] ON [c].[CreatedBy] = [u].[Id] AND [c].[Id]=@clubId); 
					SET @membersCount = (SELECT COUNT(*) FROM [UserClub] WHERE ClubId=@clubId AND IsDeleted = 0);

					IF EXISTS (SELECT * FROM [UserClub] [uc] WHERE [uc].[UserId] = @userId AND [uc].[ClubId]=@clubId AND IsDeleted = 0)
						SET @isJoined = 1;
					
					IF @isJoined = 0 AND EXISTS (SELECT * FROM [ClubRequest] [cr] WHERE [cr].[UserId]=@userId AND [cr].ClubId = @clubId AND [cr].[RequestStatus]=0)
						SET @isRequested = 1;

					INSERT INTO #TempTable VALUES (@clubId, @iconUrl, @title, @description, @isPublic, @isClosed, @createdBy, @createdOn, @membersCount, @isJoined, @isRequested); 
					FETCH NEXT FROM cursor1 INTO @clubId; 
				END; 
		CLOSE cursor1; 
	DEALLOCATE cursor1; 
	SELECT * FROM #TempTable; 
	DROP TABLE #TempTable; 
END;

GO


CREATE   PROCEDURE [GetClubMessages]
	@clubId UNIQUEIDENTIFIER,
	@receiverId UNIQUEIDENTIFIER
AS 
BEGIN 
	SELECT * FROM [dbo].[Message] WHERE ([ClubId]=@clubId AND [ReceiverId]=@receiverID) ORDER BY [TimeStamp] DESC; 
END;

GO

CREATE PROCEDURE [dbo].[GetClubNonParticipants]
	@clubId UNIQUEIDENTIFIER
AS
BEGIN
DECLARE @id UNIQUEIDENTIFIER;
DECLARE @iconUrl NVARCHAR(MAX);
DECLARE @name VARCHAR(150);
DECLARE @about VARCHAR(400);

CREATE TABLE #TempTable (
	Id UNIQUEIDENTIFIER,
	IconUrl NVARCHAR(MAX),
	[Name] VARCHAR(150),
	About VARCHAR(400));

DECLARE cursor1 CURSOR FOR (SELECT Id FROM [User] WHERE Id NOT IN (SELECT UserId FROM UserClub WHERE ClubId = @clubId));
	OPEN cursor1;
		FETCH NEXT FROM cursor1 INTO @id;
			WHILE @@FETCH_STATUS = 0
				BEGIN
					select @name = DisplayName from [User] where Id = @id;
					select @iconUrl = ProfileImageUrl, @about = About from [UserProfile] where UserId = @id;

					insert into #TempTable (
						Id,
						IconUrl,
						[Name],
						About) VALUES (@id, @iconUrl, @name, @about);
					FETCH NEXT FROM cursor1 INTO @id;
			END;
	CLOSE cursor1;
DEALLOCATE cursor1; 
SELECT * FROM #TempTable; 
DROP TABLE #TempTable; 
END;


GO


CREATE   PROCEDURE [dbo].[GetClubRequests]
	@clubId UNIQUEIDENTIFIER
AS 
BEGIN 
	DECLARE @requestId UNIQUEIDENTIFIER;
	DECLARE @userId UNIQUEIDENTIFIER;
	DECLARE @name VARCHAR(150);
	DECLARE @profileImageUrl NVARCHAR(MAX);
	DECLARE @email VARCHAR(50); 

	CREATE TABLE #TempTable (
		  Id UNIQUEIDENTIFIER,
		  [Name] VARCHAR(150),
		  ProfileImageUrl NVARCHAR(MAX),
		  Email VARCHAR(50));
	DECLARE cursor1 CURSOR FOR (SELECT [Id] FROM [ClubRequest] WHERE [ClubId]=@clubId AND [RequestStatus] = 0);
		OPEN cursor1; 
			FETCH NEXT FROM cursor1 INTO @requestId; 
			WHILE @@FETCH_STATUS = 0 
				BEGIN 
					SELECT 
						@name = [DisplayName], @email = [Email], @profileImageUrl = [ProfileImageUrl] 
					FROM [User] [u] 
					LEFT JOIN [UserProfile] [up] 
					ON [u].[Id] = [up].[UserId] WHERE [u].[Id] = (SELECT [UserId] FROM [ClubRequest] WHERE [Id] = @requestId);

					INSERT INTO #TempTable VALUES (@requestId, @name, @profileImageUrl, @email); 
					FETCH NEXT FROM cursor1 INTO @requestId; 
				END; 
		CLOSE cursor1; 
	DEALLOCATE cursor1; 
	SELECT * FROM #TempTable; 
	DROP TABLE #TempTable; 
END;

GO


CREATE   PROCEDURE [dbo].[GetParticipants]
	@clubId UNIQUEIDENTIFIER
AS
BEGIN
	SELECT [u].[Id], [up].[ProfileImageUrl], [u].[DisplayName] AS [Name], [u].[Email], [u].[Status], 
	[uc].[IsBlocked],
	(SELECT 
		CASE 
			WHEN exists (SELECT * FROM ClubAdmin WHERE UserId = [u].[Id] AND ClubId = @ClubId AND IsDeleted = 0) THEN 1
			ELSE 2
		END)
	 AS [Role]
	FROM [dbo].[User] [u] 
	JOIN [UserClub] [uc] ON [u].[Id] = [uc].[UserId] AND [uc].[ClubId] = @ClubId AND [uc].[IsDeleted] = 0
	LEFT JOIN [dbo].[UserProfile] [up] ON [u].[Id] = [up].[UserId];
END;

GO


CREATE   PROCEDURE [GetThreadMessages]
	@senderId UNIQUEIDENTIFIER,
	@receiverId UNIQUEIDENTIFIER
AS 
BEGIN 
	SELECT * FROM [dbo].[Message] WHERE [SenderId]=@senderId AND [ReceiverId]=@receiverID AND [ClubId] IS NULL ORDER BY [TimeStamp] DESC; 
END;


GO


CREATE   PROCEDURE [GetUserConnections]
	@userId UNIQUEIDENTIFIER
AS 
BEGIN 
	DECLARE @connectedUserId UNIQUEIDENTIFIER;
	DECLARE @name VARCHAR(150);
	DECLARE @profileImageUrl NVARCHAR(MAX) = null;
	DECLARE @mutualClubsCount INT = 0; 
	DECLARE @description VARCHAR(400);
	DECLARE @email VARCHAR(50);
	DECLARE @phone VARCHAR(20);

	CREATE TABLE #TempTable (
		  Id UNIQUEIDENTIFIER,
		  [Name] VARCHAR(150),
		  ProfileImageUrl NVARCHAR(MAX),
		  Phone VARCHAR(20),
		  [Description] VARCHAR(400),
		  Email VARCHAR(50),
		  MutualClubsCount INT);
	DECLARE cursor1 CURSOR FOR (SELECT [ReceiverId] FROM [Connection] WHERE [SenderId]=@userId);
		OPEN cursor1; 
			FETCH NEXT FROM cursor1 INTO @connectedUserId; 
			WHILE @@FETCH_STATUS = 0 
			BEGIN 
				SELECT 
					@name=[u].[DisplayName], @profileImageUrl=[up].[ProfileImageUrl], @email = [u].[Email], @phone = [u].[Phone], @description = [up].[About] 
				FROM [User] [u] 
				LEFT JOIN [UserProfile] [up] ON [u].[Id] = [up].[UserId] 
				WHERE u.Id=@connectedUserId;

				SET @mutualClubsCount = (SELECT COUNT(*) FROM [UserClub] [c1] JOIN [UserClub] [c2] ON [c1].[ClubId] = [c2].[ClubId] WHERE [c1].[UserId] = @userId AND [c2].[UserId] = @connectedUserId);
				
				INSERT INTO #TempTable VALUES (@connectedUserId, @name, @profileImageUrl, @phone, @description, @email, @mutualClubsCount); 
				FETCH NEXT FROM cursor1 INTO @connectedUserId; 
			END; 
		CLOSE cursor1; 
	DEALLOCATE cursor1; 
	SELECT * FROM #TempTable; 
	DROP TABLE #TempTable; 
END;


GO


CREATE    PROCEDURE GetUserThreadListItem
	@userId UNIQUEIDENTIFIER
AS 
BEGIN 
	DECLARE @friendId UNIQUEIDENTIFIER;
	DECLARE @userName VARCHAR(100);
	DECLARE @profileImageUrl NVARCHAR(MAX);
	DECLARE @receiverId UNIQUEIDENTIFIER;
	DECLARE @senderId UNIQUEIDENTIFIER;
	DECLARE @clubId UNIQUEIDENTIFIER;
	DECLARE @id UNIQUEIDENTIFIER;
	DECLARE @body NVARCHAR(MAX); 
	DECLARE @status tinyint; 
	DECLARE @attachments NVARCHAR(MAX); 
	DECLARE @timeStamp DATETIME; 
	DECLARE @unReadMessageCount INT; 
	DECLARE @isFavourite BIT; 
	DECLARE @isMuted BIT;

	CREATE TABLE #TempTable (
		  UserId UNIQUEIDENTIFIER,
		  UserName VARCHAR(100),
		  ProfileImageUrl NVARCHAR(MAX),
		  IsFavourite BIT,
		  UnReadMessageCount INT,
		  IsMuted BIT,
		  Id	 UNIQUEIDENTIFIER,
		  Body NVARCHAR(MAX), 
		  [TimeStamp] DATETIME, 
		  ClubId UNIQUEIDENTIFIER,
		  SenderId UNIQUEIDENTIFIER,
		  ReceiverId UNIQUEIDENTIFIER,
		  [Status] tinyint,
		  Attachments NVARCHAR(MAX));
	DECLARE cursor1 CURSOR FOR (SELECT ReceiverId FROM Connection WHERE [SenderId] = @userId AND [IsDeleted] = 0);
		OPEN cursor1; 
			FETCH NEXT FROM cursor1 INTO @friendId; 
			WHILE @@FETCH_STATUS = 0 
				BEGIN 
					SET @id = @friendId;
					SET @body = null;
					SET @timeStamp = null;
					SET @clubId = null;
					SET @senderId = null;
					SET @receiverId = null;
					SET @status = 0;
					SET @attachments = null;
					SET @unReadMessageCount = 0; 
					SET @isFavourite = 0;
					SET @isMuted = 0;
					SELECT @userName=[DisplayName] FROM [User] WHERE [Id]=@friendId;
					SELECT @profileImageUrl=[ProfileImageUrl] FROM [UserProfile]  WHERE [UserId]=@friendId;
					SELECT TOP 1 
						  @body = Body, 
						  @timeStamp = [TimeStamp], 
						  @clubId = ClubId,
						  @senderId = SenderId,
						  @receiverId = ReceiverId,
						  @status = [Status]
					FROM [Message] 
					WHERE ((ReceiverId = @userId AND SenderId=@friendId) OR (SenderId = @userId AND ReceiverId=@friendId)) AND ClubId IS NULL ORDER BY [TimeStamp] DESC; 

					SET @unReadMessageCount = (SELECT COUNT(*) FROM [Message] WHERE ReceiverId = @userId AND SenderId=@friendId AND [Status] = 0); 

					SELECT @isFavourite = IsFavourite, @isMuted = IsMuted FROM [Connection] WHERE SenderId=@userId AND ReceiverId=@friendId;

					INSERT INTO #TempTable (
						  UserId,
						  UserName,
						  ProfileImageUrl,
						  IsFavourite,
						  UnReadMessageCount,
						  IsMuted,
						  Id,
						  Body, 
						  [TimeStamp], 
						  ClubId,
						  SenderId,
						  ReceiverId,
						  [Status],
						  Attachments) VALUES (@friendId, @userName, @profileImageUrl, @isFavourite, @unReadMessageCount, @isMuted, @id, @body, @timeStamp, @clubId, @senderId, @receiverId, @status, @attachments); 
					FETCH NEXT FROM cursor1 INTO @friendId;
			END; 
		CLOSE cursor1; 
	DEALLOCATE cursor1; 
	SELECT * FROM #TempTable; 
	DROP TABLE #TempTable; 
END;


