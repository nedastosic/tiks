USE [master]
GO
/****** Object:  Database [SkiPass]    Script Date: 22.8.2020. 13:57:25 ******/
CREATE DATABASE [SkiPass]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'SkiPass', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.SQLEXPRESS\MSSQL\DATA\SkiPass.mdf' , SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'SkiPass_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.SQLEXPRESS\MSSQL\DATA\SkiPass_log.ldf' , SIZE = 8192KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT
GO
ALTER DATABASE [SkiPass] SET COMPATIBILITY_LEVEL = 150
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [SkiPass].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [SkiPass] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [SkiPass] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [SkiPass] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [SkiPass] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [SkiPass] SET ARITHABORT OFF 
GO
ALTER DATABASE [SkiPass] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [SkiPass] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [SkiPass] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [SkiPass] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [SkiPass] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [SkiPass] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [SkiPass] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [SkiPass] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [SkiPass] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [SkiPass] SET  DISABLE_BROKER 
GO
ALTER DATABASE [SkiPass] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [SkiPass] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [SkiPass] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [SkiPass] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [SkiPass] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [SkiPass] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [SkiPass] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [SkiPass] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [SkiPass] SET  MULTI_USER 
GO
ALTER DATABASE [SkiPass] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [SkiPass] SET DB_CHAINING OFF 
GO
ALTER DATABASE [SkiPass] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [SkiPass] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [SkiPass] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [SkiPass] SET QUERY_STORE = OFF
GO
USE [SkiPass]
GO
/****** Object:  Table [dbo].[Package]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Package](
	[PackageID] [bigint] NOT NULL,
	[Name] [varchar](50) NULL,
 CONSTRAINT [PK_Package] PRIMARY KEY CLUSTERED 
(
	[PackageID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PackageRegion]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PackageRegion](
	[PackageID] [bigint] NOT NULL,
	[RegionID] [bigint] NOT NULL,
	[CreationDate] [date] NULL,
 CONSTRAINT [PK_PackageRegion] PRIMARY KEY CLUSTERED 
(
	[PackageID] ASC,
	[RegionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Region]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Region](
	[RegionID] [bigint] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NULL,
 CONSTRAINT [PK_Region] PRIMARY KEY CLUSTERED 
(
	[RegionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Rental]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Rental](
	[RentalDate] [datetime] NOT NULL,
	[UserID] [bigint] NOT NULL,
	[SkiPassID] [bigint] NOT NULL,
	[ValidFrom] [datetime] NULL,
	[ValidTo] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[RentalDate] ASC,
	[UserID] ASC,
	[SkiPassID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SkiPass]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SkiPass](
	[SkiPassID] [bigint] IDENTITY(1,1) NOT NULL,
	[Price] [decimal](18, 2) NULL,
	[Status] [bit] NULL,
	[PackageID] [bigint] NULL,
 CONSTRAINT [PK_SkiPass] PRIMARY KEY CLUSTERED 
(
	[SkiPassID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SkiSlope]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SkiSlope](
	[SlopeID] [bigint] NOT NULL,
	[RegionID] [bigint] NOT NULL,
	[Name] [varchar](50) NULL,
	[Capacity] [int] NULL,
	[Price] [float] NULL,
	[SlopeTypeID] [bigint] NULL,
PRIMARY KEY CLUSTERED 
(
	[SlopeID] ASC,
	[RegionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SkiSlopeType]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SkiSlopeType](
	[SkiSlopeTypeID] [bigint] NOT NULL,
	[Name] [varchar](50) NULL,
 CONSTRAINT [PK_TrailType] PRIMARY KEY CLUSTERED 
(
	[SkiSlopeTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[User]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[User](
	[UserID] [bigint] IDENTITY(1,1) NOT NULL,
	[Firstname] [varchar](50) NULL,
	[Lastname] [varchar](50) NULL,
	[JMBG] [varchar](13) NULL,
	[DateOfBirth] [date] NULL,
	[Phone] [varchar](50) NULL,
	[Email] [varchar](50) NULL,
 CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
INSERT [dbo].[Package] ([PackageID], [Name]) VALUES (1, N'A')
INSERT [dbo].[Package] ([PackageID], [Name]) VALUES (2, N'B')
INSERT [dbo].[Package] ([PackageID], [Name]) VALUES (3, N'C')
INSERT [dbo].[Package] ([PackageID], [Name]) VALUES (4, N'D')
INSERT [dbo].[Package] ([PackageID], [Name]) VALUES (5, N'E')
GO
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (1, 1, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (1, 2, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (1, 3, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (1, 4, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (1, 5, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (1, 6, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (2, 1, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (2, 3, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (2, 5, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (3, 1, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (3, 2, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (3, 3, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (5, 3, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (5, 4, CAST(N'2020-07-18' AS Date))
INSERT [dbo].[PackageRegion] ([PackageID], [RegionID], [CreationDate]) VALUES (5, 5, CAST(N'2020-07-18' AS Date))
GO
SET IDENTITY_INSERT [dbo].[Region] ON 

INSERT [dbo].[Region] ([RegionID], [Name]) VALUES (1, N'Caron')
INSERT [dbo].[Region] ([RegionID], [Name]) VALUES (2, N'Orelle')
INSERT [dbo].[Region] ([RegionID], [Name]) VALUES (3, N'Pelcet')
INSERT [dbo].[Region] ([RegionID], [Name]) VALUES (4, N'Plein Sud')
INSERT [dbo].[Region] ([RegionID], [Name]) VALUES (5, N'Thorens')
INSERT [dbo].[Region] ([RegionID], [Name]) VALUES (6, N'Espaces Ludiques')
SET IDENTITY_INSERT [dbo].[Region] OFF
GO
INSERT [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID], [ValidFrom], [ValidTo]) VALUES (CAST(N'2012-06-18T10:34:09.000' AS DateTime), 2, 2, CAST(N'2012-06-18T10:34:09.000' AS DateTime), CAST(N'2012-06-18T10:34:09.000' AS DateTime))
INSERT [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID], [ValidFrom], [ValidTo]) VALUES (CAST(N'2012-06-20T10:34:09.000' AS DateTime), 2, 2, CAST(N'2012-06-18T10:34:09.000' AS DateTime), CAST(N'2012-06-20T10:34:09.000' AS DateTime))
INSERT [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID], [ValidFrom], [ValidTo]) VALUES (CAST(N'2020-07-18T00:00:00.000' AS DateTime), 1, 1, CAST(N'2020-07-21T00:00:00.000' AS DateTime), CAST(N'2020-07-21T00:00:00.000' AS DateTime))
INSERT [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID], [ValidFrom], [ValidTo]) VALUES (CAST(N'2020-07-18T19:31:35.517' AS DateTime), 1, 1, CAST(N'2019-12-29T00:00:00.000' AS DateTime), CAST(N'2019-01-03T00:00:00.000' AS DateTime))
INSERT [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID], [ValidFrom], [ValidTo]) VALUES (CAST(N'2020-07-18T19:32:23.723' AS DateTime), 1, 1, CAST(N'2019-12-29T00:00:00.000' AS DateTime), CAST(N'2020-01-03T00:00:00.000' AS DateTime))
INSERT [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID], [ValidFrom], [ValidTo]) VALUES (CAST(N'2020-07-19T00:00:00.000' AS DateTime), 1, 1, CAST(N'2020-07-21T00:00:00.000' AS DateTime), CAST(N'2020-07-21T00:00:00.000' AS DateTime))
INSERT [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID], [ValidFrom], [ValidTo]) VALUES (CAST(N'2020-07-20T00:00:00.000' AS DateTime), 1, 1, CAST(N'2020-07-21T00:00:00.000' AS DateTime), CAST(N'2020-07-21T00:00:00.000' AS DateTime))
INSERT [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID], [ValidFrom], [ValidTo]) VALUES (CAST(N'2020-07-25T00:00:00.000' AS DateTime), 1, 1, CAST(N'2020-07-21T00:00:00.000' AS DateTime), CAST(N'2020-07-27T00:00:00.000' AS DateTime))
GO
SET IDENTITY_INSERT [dbo].[SkiPass] ON 

INSERT [dbo].[SkiPass] ([SkiPassID], [Price], [Status], [PackageID]) VALUES (1, CAST(390.60 AS Decimal(18, 2)), 1, 1)
INSERT [dbo].[SkiPass] ([SkiPassID], [Price], [Status], [PackageID]) VALUES (2, CAST(56.22 AS Decimal(18, 2)), 1, 2)
INSERT [dbo].[SkiPass] ([SkiPassID], [Price], [Status], [PackageID]) VALUES (3, CAST(2.00 AS Decimal(18, 2)), 1, 3)
INSERT [dbo].[SkiPass] ([SkiPassID], [Price], [Status], [PackageID]) VALUES (4, CAST(2.00 AS Decimal(18, 2)), 1, 3)
SET IDENTITY_INSERT [dbo].[SkiPass] OFF
GO
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (1, 1, N'Blanchot', 500, 0.76, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (2, 1, N'Bvd Cumin Haut', 450, 0.63, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (3, 1, N'Gentiane', 300, 0.5, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (4, 1, N'Lagopede', 360, 0.65, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (5, 1, N'Les ours', 200, 0.4, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (6, 1, N'Linotte', 600, 1, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (7, 1, N'Lou', 470, 0.8, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (8, 1, N'Tetras', 390, 0.75, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (9, 1, N'Boismint', 400, 0.69, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (10, 1, N'Col De L Audzin', 450, 0.86, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (11, 1, N'Arolle', 290, 0.95, 4)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (12, 1, N'Cime', 500, 0.79, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (13, 1, N'Armoise', 460, 0.87, 4)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (14, 1, N'Ours', 700, 1.2, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (15, 2, N'Tourbiere', 620, 1.1, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (16, 2, N'Les Gentianes', 400, 0.85, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (17, 2, N'Lory', 365, 0.46, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (18, 2, N'Bouchet', 290, 0.39, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (19, 2, N'Coraia', 360, 0.69, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (20, 2, N'Mauriennaise', 450, 0.95, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (21, 2, N'Combe De Rosael', 620, 1.3, 4)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (22, 2, N'Le Croix D''Antide', 425, 0.95, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (23, 2, N'Gentianes', 350, 0.85, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (24, 2, N'Gentianes', 400, 0.9, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (25, 2, N'Peyron', 385, 0.93, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (26, 3, N'2 Combes', 460, 0.96, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (27, 3, N'Espace Juniors', 360, 0.87, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (28, 3, N'Grenouillere', 400, 0.65, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (29, 3, N'P Campagnols', 430, 0.75, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (30, 3, N'P Musaraigne', 400, 0.67, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (31, 3, N'Roc', 460, 0.78, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (32, 3, N'Chalete', 200, 0.35, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (33, 3, N'Hermine', 350, 0.49, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (34, 3, N'Les Bleuts', 380, 0.6, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (35, 3, N'Les Dalles', 390, 0.65, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (36, 3, N'Tete Ronde', 420, 0.7, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (37, 3, N'Ardoises', 450, 0.82, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (38, 3, N'Beranger Bas', 500, 0.89, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (39, 3, N'Beranger Haut', 520, 0.95, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (40, 3, N'Christine', 530, 0.98, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (41, 3, N'Croissant', 410, 0.79, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (42, 3, N'Les Blanc', 400, 0.75, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (43, 3, N'Lauzes', 250, 0.45, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (44, 3, N'Les Vires', 300, 0.56, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (45, 3, N'Cascades', 350, 0.7, 4)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (46, 3, N'Yannick Richard', 420, 0.85, 4)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (47, 3, N'Vires', 395, 0.92, 4)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (48, 3, N'Bleuets', 250, 0.43, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (49, 3, N'Musaraigne', 650, 1.4, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (50, 4, N'La Voie Lactee', 360, 0.72, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (51, 4, N'Acces Ucpa', 370, 0.74, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (52, 4, N'Bvd Goitschel', 380, 0.78, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (53, 4, N'Cairn', 430, 0.86, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (54, 4, N'Pluviometre', 450, 0.93, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (55, 4, N'Retour Sud', 490, 0.95, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (56, 4, N'Chasse', 590, 1.3, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (57, 4, N'Les Chardons', 620, 1.4, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (58, 4, N'Le Triton', 640, 1.8, 4)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (59, 4, N'Corniche', 420, 0.62, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (60, 4, N'Val Tho', 400, 0.78, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (61, 5, N'Chombe De Thorens', 380, 0.75, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (62, 5, N'Family Park', 700, 1.8, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (63, 5, N'Le Flocon', 470, 0.81, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (64, 5, N'Bvd Rosael', 490, 0.84, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (65, 5, N'Genepi', 250, 0.65, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (66, 5, N'Le Chocard', 390, 0.71, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (67, 5, N'Moraine', 420, 0.75, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (68, 5, N'Niverolle', 430, 0.76, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (69, 5, N'Plateau', 370, 0.65, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (70, 5, N'Falaise', 450, 0.87, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (71, 5, N'Le Col', 690, 1.35, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (72, 5, N'Les Asters', 290, 0.39, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (73, 5, N'Rhodos', 500, 1.2, 3)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (74, 5, N'Camille', 100, 0.2, 1)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (75, 5, N'Vt Park', 250, 0.5, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (76, 6, N'Tyrolienne Orelle', 300, 0.75, 2)
INSERT [dbo].[SkiSlope] ([SlopeID], [RegionID], [Name], [Capacity], [Price], [SlopeTypeID]) VALUES (77, 6, N'Tyrolienne La Bee', 350, 0.84, 1)
GO
INSERT [dbo].[SkiSlopeType] ([SkiSlopeTypeID], [Name]) VALUES (1, N'Green')
INSERT [dbo].[SkiSlopeType] ([SkiSlopeTypeID], [Name]) VALUES (2, N'Blue')
INSERT [dbo].[SkiSlopeType] ([SkiSlopeTypeID], [Name]) VALUES (3, N'Red')
INSERT [dbo].[SkiSlopeType] ([SkiSlopeTypeID], [Name]) VALUES (4, N'Black')
GO
SET IDENTITY_INSERT [dbo].[User] ON 

INSERT [dbo].[User] ([UserID], [Firstname], [Lastname], [JMBG], [DateOfBirth], [Phone], [Email]) VALUES (1, N'Milica', N'Milic', N'3011973387483', CAST(N'1973-11-30' AS Date), N'+381645869852', N'milicamilic@gmail.com')
INSERT [dbo].[User] ([UserID], [Firstname], [Lastname], [JMBG], [DateOfBirth], [Phone], [Email]) VALUES (2, N'Dušan', N'Milicevic', N'1001978334270', CAST(N'1978-01-10' AS Date), N'0605698952', N'dusan1978@gmail.com')
INSERT [dbo].[User] ([UserID], [Firstname], [Lastname], [JMBG], [DateOfBirth], [Phone], [Email]) VALUES (3, N'Ana', N'Nestorovic', N'0303994385928', CAST(N'1994-03-03' AS Date), N'+381063569856', N'ananestorovic@gmail.com')
SET IDENTITY_INSERT [dbo].[User] OFF
GO
ALTER TABLE [dbo].[PackageRegion]  WITH CHECK ADD FOREIGN KEY([PackageID])
REFERENCES [dbo].[Package] ([PackageID])
GO
ALTER TABLE [dbo].[PackageRegion]  WITH CHECK ADD FOREIGN KEY([RegionID])
REFERENCES [dbo].[Region] ([RegionID])
GO
ALTER TABLE [dbo].[Rental]  WITH CHECK ADD  CONSTRAINT [FK_Rental_SkiPass] FOREIGN KEY([SkiPassID])
REFERENCES [dbo].[SkiPass] ([SkiPassID])
GO
ALTER TABLE [dbo].[Rental] CHECK CONSTRAINT [FK_Rental_SkiPass]
GO
ALTER TABLE [dbo].[Rental]  WITH CHECK ADD  CONSTRAINT [FK_Rental_User] FOREIGN KEY([RentalDate], [UserID], [SkiPassID])
REFERENCES [dbo].[Rental] ([RentalDate], [UserID], [SkiPassID])
GO
ALTER TABLE [dbo].[Rental] CHECK CONSTRAINT [FK_Rental_User]
GO
ALTER TABLE [dbo].[SkiPass]  WITH CHECK ADD FOREIGN KEY([PackageID])
REFERENCES [dbo].[Package] ([PackageID])
GO
ALTER TABLE [dbo].[SkiSlope]  WITH CHECK ADD  CONSTRAINT [FK_Trail_Region] FOREIGN KEY([RegionID])
REFERENCES [dbo].[Region] ([RegionID])
GO
ALTER TABLE [dbo].[SkiSlope] CHECK CONSTRAINT [FK_Trail_Region]
GO
ALTER TABLE [dbo].[SkiSlope]  WITH CHECK ADD  CONSTRAINT [FK_Trail_Type] FOREIGN KEY([SlopeTypeID])
REFERENCES [dbo].[SkiSlopeType] ([SkiSlopeTypeID])
GO
ALTER TABLE [dbo].[SkiSlope] CHECK CONSTRAINT [FK_Trail_Type]
GO
/****** Object:  StoredProcedure [dbo].[Insert_rental]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Insert_rental] 
       @RentalDate                  DATETIME, 
       @UserID						 BIGINT, 
       @SkiPassID                  BIGINT, 
       @ValidFrom					 DATETIME,
	   @ValidTo					 DATETIME
AS 
BEGIN 
     SET NOCOUNT ON 

	 
	 IF @ValidTo < @ValidFrom  
	 BEGIN
	 RAISERROR ('Date "Valid to" must be after date "Valid from"!',1,1)
	 RETURN
	 END
	 

     INSERT INTO dbo.Rental
          (                    
            RentalDate                     ,
            UserID                  ,
            SkiPassID                      ,
            ValidFrom,
			ValidTo
          ) 
     VALUES 
          ( 
           @RentalDate                     ,
            @UserID                  ,
            @SkiPassID                      ,
            @ValidFrom,
			@ValidTo
          ) 

END 
GO
/****** Object:  StoredProcedure [dbo].[Insert_ski_pass]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Insert_ski_pass] 
       @SkiPassID                  BIGINT, 
       @Price						 FLOAT = 0, 
       @Status                  BIT = 1, 
       @PackageID					 BIGINT
AS 
BEGIN 
     SET NOCOUNT ON 

     INSERT INTO dbo.SkiPass
          (                    
            SkiPassID,
			Price,
			Status,
			PackageID
          ) 
     VALUES 
          ( 
           @SkiPassID,
			@Price,
			@Status,
			@PackageID
          ) 

END 
GO
/****** Object:  StoredProcedure [dbo].[Insert_user]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Insert_user] 
       @UserID BIGINT,
	   @Firstname VARCHAR(50),
	   @Lastname VARCHAR(50),
	   @JMBG VARCHAR(13),
	   @DateOfBirth DATE,
	   @Phone VARCHAR(50),
	   @Email VARCHAR(50)
AS 
BEGIN 
     SET NOCOUNT ON 

     INSERT INTO dbo."User"
          (                    
             UserID ,
	   Firstname ,
	   Lastname ,
	   JMBG ,
	   DateOfBirth ,
	   Phone ,
	   Email 
          ) 
     VALUES 
          ( 
           @UserID ,
	   @Firstname ,
	   @Lastname ,
	   @JMBG ,
	   @DateOfBirth ,
	   @Phone ,
	   @Email 
          ) 

END 
GO
/****** Object:  Trigger [dbo].[trg_calculate_price]    Script Date: 22.8.2020. 13:57:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[trg_calculate_price]
ON [dbo].[Rental]
AFTER INSERT
AS
DECLARE @ski_pass_id bigint;
DECLARE @rental_date datetime;
DECLARE @user_id bigint;
DECLARE @slope_prices_sum float;
DECLARE @days int;
BEGIN;
	select @ski_pass_id = SkiPassID, @rental_date = RentalDate, @user_id = UserID
	from inserted;

	select @days = DATEDIFF(day, ValidFrom, ValidTo)
	from Rental
	where SkiPassID = @ski_pass_id and RentalDate = @rental_date and UserID = @user_id;

	select @slope_prices_sum = sum(ski_slope.price)
	from dbo.SkiSlope as ski_slope 
	join dbo.Region as region on ski_slope.RegionID = region.RegionID
	join dbo.PackageRegion as package_region on region.RegionID = package_region.PackageID
	join dbo.Package as package on package_region.PackageID = package.PackageID
	join dbo.SkiPass as ski_pass on package.PackageID = ski_pass.PackageID
	where ski_pass.SkiPassID = @ski_pass_id;

    UPDATE dbo.SkiPass set price = @slope_prices_sum * @days where SkiPassID = @ski_pass_id;


END
GO
ALTER TABLE [dbo].[Rental] ENABLE TRIGGER [trg_calculate_price]
GO
USE [master]
GO
ALTER DATABASE [SkiPass] SET  READ_WRITE 
GO
