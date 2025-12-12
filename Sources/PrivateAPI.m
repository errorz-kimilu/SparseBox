//
//  PrivateAPI.m
//  SparseBox
//
//  Created by Duy Tran on 12/12/25.
//

#import "SparseBox-Bridging-Header.h"

LSApplicationWorkspace *LSApplicationWorkspaceDefaultWorkspace(void) {
   return [NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace];
}
